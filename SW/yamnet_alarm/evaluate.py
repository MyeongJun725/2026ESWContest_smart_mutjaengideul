"""Offline 16kHz WAV check. Does not publish alerts or access the microphone."""

import argparse
import json
import os
from pathlib import Path
import resource
import time
import wave

import numpy as np
from ai_edge_litert.interpreter import Interpreter
from detection import AlarmPolicy


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--labels", required=True)
    parser.add_argument("--wav", nargs="+", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    os.nice(15)
    labels = Path(args.labels).read_text().splitlines()
    model = Interpreter(model_path=args.model, num_threads=1)
    model.allocate_tensors()
    input_id, output_id = (
        model.get_input_details()[0]["index"],
        model.get_output_details()[0]["index"],
    )
    results, timings = [], []
    for name in args.wav:
        with wave.open(name) as stream:
            if (
                stream.getframerate(),
                stream.getnchannels(),
                stream.getsampwidth(),
            ) != (16000, 1, 2):
                raise ValueError("Expected mono signed PCM16 16kHz fixture")
            audio = (
                np.frombuffer(
                    stream.readframes(stream.getnframes()), dtype="<i2"
                ).astype(np.float32)
                / 32768
            )
        policy, events, frames = AlarmPolicy(), [], []
        for index in range(0, len(audio) - 15600 + 1, 7680):
            began = time.perf_counter()
            model.set_tensor(input_id, audio[index : index + 15600])
            model.invoke()
            scores = model.get_tensor(output_id)[0]
            elapsed = (time.perf_counter() - began) * 1000
            timings.append(elapsed)
            top = np.argsort(scores)[-3:][::-1]
            event = policy.update(dict(zip(labels, scores)), index / 16000)
            if event:
                events.append(event)
            frames.append(
                dict(
                    at=round(index / 16000, 2),
                    top=[
                        dict(label=labels[i], score=round(float(scores[i]), 4))
                        for i in top
                    ],
                )
            )
        results.append(dict(file=Path(name).name, events=events, frames=frames))
    report = dict(
        engine="actual YAMNet model on Pi5, prerecorded fixtures, not live microphone",
        threads=1,
        median_ms=float(np.median(timings)),
        p95_ms=float(np.percentile(timings, 95)),
        max_ms=max(timings),
        peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        fixtures=results,
    )
    Path(args.output).write_text(json.dumps(report, indent=2))
    print(json.dumps({k: v for k, v in report.items() if k != "fixtures"}))
    print(json.dumps([dict(file=r["file"], events=r["events"]) for r in results]))


if __name__ == "__main__":
    main()
