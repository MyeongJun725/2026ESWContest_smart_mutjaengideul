"""Read an existing inference process; never open or restart a camera."""
import argparse
import json
import math
import os
from pathlib import Path
import time


def processing_summary(rows):
    values = []
    for row in rows:
        try:
            value = float(row["processing_ms"])
        except (KeyError, TypeError, ValueError):
            continue
        if math.isfinite(value) and value >= 0:
            values.append(value)
    return {"measured_frames": len(values), "max_processing_ms": max(values, default=None)}


def process_paths(pid, proc_root=Path("/proc")):
    base = proc_root / str(pid)
    args = (base / "cmdline").read_bytes().rstrip(b"\0").split(b"\0")
    if len(args) < 5 or Path(os.fsdecode(args[0])).name != "vision_stream_sign_live_mqtt_rpi4":
        raise ValueError("PID does not use the supported live inference command line")
    log = Path(os.readlink(base / "fd/2"))
    if not log.is_absolute() or not log.is_file():
        raise ValueError("Actual stderr is not a readable regular log file")
    # The deployed command is EXE WIDTH HEIGHT MODEL_DIR JSONL DURATION RUNTIME.
    return Path(os.fsdecode(args[4])), log


def mark(path):
    info = path.stat()
    return info.st_dev, info.st_ino, info.st_size


def read_new(path, before):
    current = path.stat()
    if (current.st_dev, current.st_ino) != before[:2] or current.st_size < before[2]:
        raise RuntimeError("Log rotated/truncated during capture; discard this measurement")
    with path.open("rb") as stream:
        stream.seek(before[2])
        return stream.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", required=True, type=int)
    parser.add_argument("--expected", required=True, help="Explicit ground truth, e.g. WORD1229; never inferred from filenames")
    parser.add_argument("--seconds", type=float, default=15)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 0 < args.seconds <= 120:
        parser.error("seconds must be in (0,120]")
    json_path, stderr_path = process_paths(args.pid)
    json_mark, log_mark = mark(json_path), mark(stderr_path)
    start_ticks = (Path(f"/proc/{args.pid}/stat").read_text().split(") ", 1)[1].split())[19]
    time.sleep(args.seconds)
    current_ticks = (Path(f"/proc/{args.pid}/stat").read_text().split(") ", 1)[1].split())[19]
    if start_ticks != current_ticks:
        raise RuntimeError("Inference process changed during capture")
    json_bytes, log_bytes = read_new(json_path, json_mark), read_new(stderr_path, log_mark)
    # The capture may start/end inside a write. Only parse complete JSON lines.
    rows=[]
    for line in json_bytes.splitlines():
        try:
            row=json.loads(line)
            if isinstance(row,dict): rows.append(row)
        except (ValueError, UnicodeDecodeError):
            continue
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / "frames.jsonl").write_bytes(json_bytes)
    (args.output / "actual-stderr.log").write_bytes(log_bytes)
    summary={"expected":args.expected,"pid":args.pid,"json_path":str(json_path),
        "stderr_path":str(stderr_path),"frames":len(rows),**processing_summary(rows)}
    (args.output / "summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps(summary,ensure_ascii=False))


if __name__ == "__main__":
    main()
