"""YAMNet inference from the existing STT PCM stream, entirely on Pi5."""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import signal
import socket
import threading
import time
import uuid
from urllib.parse import urlsplit

import numpy as np
from ai_edge_litert.interpreter import Interpreter
from detection import AlarmPolicy
from pcm_stream import HEADER, PcmWindows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--labels", required=True)
    parser.add_argument("--socket", default="/run/safehub-yamnet/audio.sock")
    parser.add_argument("--port", type=int, default=9381)
    args = parser.parse_args()
    labels = Path(args.labels).read_text().splitlines()
    model = Interpreter(model_path=args.model, num_threads=1)
    model.allocate_tensors()
    input_id = model.get_input_details()[0]["index"]
    output_id = model.get_output_details()[0]["index"]
    if model.get_input_details()[0]["shape"].tolist() != [15600] or len(labels) != 521:
        raise RuntimeError("Unexpected YAMNet model/label shape")
    model.set_tensor(input_id, np.zeros(15600, dtype=np.float32))
    model.invoke()
    stopped = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stopped.set())
    signal.signal(signal.SIGINT, lambda *_: stopped.set())
    lock = threading.Lock()
    state = dict(
        engine="yamnet",
        ready=True,
        audio_received_at=None,
        inference_ms=None,
        top=[],
        event=None,
        stream_resets=0,
        frames_processed=0,
        alarm_scores={},
        audio_rms=0.0,
    )
    event_at = 0.0
    token = uuid.uuid4().hex
    number = 0

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if urlsplit(self.path).path not in ("/state", "/health"):
                self.send_error(404)
                return
            with lock:
                result = dict(state)
                stamp = result.pop("audio_received_at")
                result["audio_age_seconds"] = (
                    None if stamp is None else time.monotonic() - stamp
                )
                result["event_age_seconds"] = (
                    None if not result["event"] else time.monotonic() - event_at
                )
            body = json.dumps(result).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_):
            pass

    http = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    threading.Thread(target=http.serve_forever, daemon=True).start()
    path = Path(args.socket)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.exists():
        path.unlink()
    receiver = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    receiver.bind(str(path))
    path.chmod(0o600)
    receiver.settimeout(0.25)
    windows, policy = PcmWindows(), AlarmPolicy()
    generation = windows.generation
    print("YAMNet ready: shared local PCM, no microphone device opened", flush=True)
    try:
        while not stopped.is_set():
            try:
                packet = receiver.recv(HEADER.size + 6401)
            except socket.timeout:
                continue
            audio = windows.accept(packet)
            if generation != windows.generation:
                generation = windows.generation
                policy.reset()
            if audio is None:
                continue
            began = time.monotonic()
            waveform = np.frombuffer(audio, dtype="<i2").astype(np.float32) / 32768
            model.set_tensor(input_id, waveform)
            model.invoke()
            scores = model.get_tensor(output_id)[0]
            duration = (time.monotonic() - began) * 1000
            top = np.argsort(scores)[-3:][::-1]
            detected = policy.update(dict(zip(labels, scores)), began)
            with lock:
                state.update(
                    audio_received_at=began,
                    inference_ms=round(duration, 2),
                    stream_resets=generation,
                    top=[dict(label=labels[i], score=float(scores[i])) for i in top],
                    frames_processed=state['frames_processed'] + 1,
                    audio_rms=round(float(np.sqrt(np.mean(waveform * waveform))), 6),
                    alarm_scores={name: float(scores[labels.index(name)]) for name in
                                  ('Fire alarm', 'Smoke detector, smoke alarm', 'Civil defense siren', 'Siren', 'Alarm')},
                )
                if detected:
                    number += 1
                    state["event"] = dict(
                        id=f"yamnet:{token}:{number}",
                        source="yamnet",
                        timestamp=time.time(),
                        stream_generation=generation,
                        **detected,
                    )
                    event_at = time.monotonic()
                    print("Alarm sound detected: " + detected["label"], flush=True)
    finally:
        receiver.close()
        path.unlink(missing_ok=True)
        http.shutdown()


if __name__ == "__main__":
    main()
