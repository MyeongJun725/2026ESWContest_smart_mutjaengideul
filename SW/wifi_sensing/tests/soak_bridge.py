"""Bounded synthetic HTTP soak in a private temporary workspace and random port.

This measures this host's software lifecycle, not RF behavior or Raspberry Pi speed.
"""

import argparse
from collections import deque
import ctypes
from datetime import datetime, timezone
import hashlib
from http.server import ThreadingHTTPServer
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bridge import Controller, Handler, RUNTIME


def rss_bytes():
    if os.name == 'nt':
        from ctypes import wintypes

        class MemoryCounters(ctypes.Structure):
            _fields_ = [('cb', wintypes.DWORD), ('PageFaultCount', wintypes.DWORD),
                        ('PeakWorkingSetSize', ctypes.c_size_t), ('WorkingSetSize', ctypes.c_size_t),
                        ('QuotaPeakPagedPoolUsage', ctypes.c_size_t), ('QuotaPagedPoolUsage', ctypes.c_size_t),
                        ('QuotaPeakNonPagedPoolUsage', ctypes.c_size_t), ('QuotaNonPagedPoolUsage', ctypes.c_size_t),
                        ('PagefileUsage', ctypes.c_size_t), ('PeakPagefileUsage', ctypes.c_size_t)]

        counters = MemoryCounters()
        counters.cb = ctypes.sizeof(counters)
        process = ctypes.windll.kernel32.GetCurrentProcess
        process.restype = wintypes.HANDLE
        query = ctypes.windll.psapi.GetProcessMemoryInfo
        query.argtypes = [wintypes.HANDLE, ctypes.POINTER(MemoryCounters), wintypes.DWORD]
        if not query(process(), ctypes.byref(counters), counters.cb):
            raise ctypes.WinError()
        return counters.WorkingSetSize
    statm = Path('/proc/self/statm')
    if statm.exists():
        return int(statm.read_text().split()[1]) * os.sysconf('SC_PAGE_SIZE')
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--seconds', type=int, default=300)
    parser.add_argument('--checkpoint-seconds', type=int, default=60)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not 15 <= args.seconds <= 3600:
        parser.error('--seconds must be 15..3600')
    if not 1 <= args.checkpoint_seconds <= 60:
        parser.error('--checkpoint-seconds must be 1..60')
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    checkpoints, errors = deque(maxlen=121), deque(maxlen=20)
    source_hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
                     for name in ('bridge.py', 'stream.py', 'runtime/LOCAL_SOURCE_MANIFEST.json')}
    result = {'scope': 'synthetic input only; current host; no physical devices',
              'source_sha256': source_hashes, 'requested_seconds': args.seconds,
              'started_utc': datetime.now(timezone.utc).isoformat(),
              'status': 'starting', 'poll_interval_seconds': .5}
    controller = server = server_thread = None
    observed = {'received': 0, 'max_arrival_gap_seconds': 0.0, 'arrival_gaps_over_150ms': 0}
    arrival_lock = threading.Lock()
    last_arrival = None
    polls = failures = saved_checks = stale_polls = 0
    max_poll_seconds = 0.0
    poll_samples = deque(maxlen=120)
    capture_started = False
    started = time.perf_counter()
    cpu_started = time.process_time()

    def write_report(status):
        elapsed = time.perf_counter() - started
        with arrival_lock:
            arrivals = dict(observed)
        sample = {'elapsed_seconds': round(elapsed, 3), 'rss_bytes': rss_bytes(),
                  'cpu_seconds': round(time.process_time() - cpu_started, 3),
                  'thread_count': threading.active_count(), 'http_polls': polls,
                  'http_failures': failures, 'max_poll_seconds': round(max_poll_seconds, 4),
                  'stale_polls_after_warmup': stale_polls,
                  'recent_mean_poll_seconds': round(sum(poll_samples) / len(poll_samples), 4) if poll_samples else None,
                  **arrivals}
        sample['received_hz'] = round(arrivals['received'] / elapsed, 3) if elapsed >= 1 else None
        sample['cpu_percent_one_core'] = round(sample['cpu_seconds'] / elapsed * 100, 2) if elapsed >= 1 else None
        if controller is not None:
            with controller.stream.lock:
                sample['buffer_frames'] = len(controller.stream.frames)
            with controller.waveform_lock:
                sample['preprocessing'] = dict(controller.waveform_stats)
            sample['record_count'] = len(controller.record_summaries())
            sample['model_metadata_cache_entries'] = len(controller.model_index)
        checkpoints.append(sample)
        result.update(status=status, latest=sample, checkpoints=list(checkpoints),
                      errors=list(errors), saved_record_checks=saved_checks)
        temporary = output.with_name(output.name + '.tmp')
        temporary.write_text(json.dumps(result, indent=2), encoding='utf-8')
        temporary.replace(output)

    # TemporaryDirectory owns only this test-created workspace; no user paths are opened.
    try:
        with tempfile.TemporaryDirectory(prefix='safehub-soak-') as folder:
            try:
                controller = Controller(folder, allow_training=False, allow_dummy=True)
                from soom_engine import verify_vendor
                verify_vendor()
                manifest = json.loads((RUNTIME / 'LOCAL_SOURCE_MANIFEST.json').read_text())
                assert all(hashlib.sha256((RUNTIME / name).read_bytes()).hexdigest() == digest
                           for name, digest in manifest['files'].items())
                server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
                server.controller = controller
                server_thread = threading.Thread(target=server.serve_forever, daemon=True)
                server_thread.start()
                base = f'http://127.0.0.1:{server.server_port}'

                def request(path, body=None):
                    req = urllib.request.Request(base + path,
                        data=None if body is None else json.dumps(body).encode(),
                        headers={'Content-Type': 'application/json'})
                    with urllib.request.urlopen(req, timeout=10) as response:
                        return json.load(response)

                append = controller.stream._append

                def observe(frame):
                    nonlocal last_arrival
                    arrived = time.perf_counter()
                    with arrival_lock:
                        if last_arrival is not None:
                            gap = arrived - last_arrival
                            observed['max_arrival_gap_seconds'] = max(observed['max_arrival_gap_seconds'], gap)
                            observed['arrival_gaps_over_150ms'] += int(gap > .15)
                        last_arrival = arrived
                        observed['received'] += 1
                    append(frame)

                controller.stream._append = observe
                request('/command/connect', {'mode': 'dummy'})
                started, cpu_started = time.perf_counter(), time.process_time()
                next_poll, next_checkpoint = started, started
                write_report('running')
                while time.perf_counter() - started < args.seconds:
                    time.sleep(max(0, next_poll - time.perf_counter()))
                    tick = time.perf_counter()
                    try:
                        state = request('/state')
                        polls += 1
                        assert state['mode'] == 'dummy' and state['hardware'] == 'synthetic'
                        assert not state['training_allowed']
                        assert not state['storage_warnings']
                        if time.perf_counter() - started > 4 and not state['fresh']:
                            stale_polls += 1
                        if state['waveform'] is not None:
                            assert len(state['waveform']['signal']) == 240
                            if not capture_started:
                                request('/command/capture', {'label': '정지', 'seconds': 4, 'round': 'synthetic-soak'})
                                capture_started = True
                        if state['capture'] and state['capture']['state'] == 'failed':
                            raise AssertionError('synthetic capture failed')
                        for record in state['records']:
                            assert record['collection']['mode'] == 'dummy'
                        if state['capture'] and state['capture']['saved']:
                            assert len(state['records']) == 1
                            saved_checks += 1
                        assert len(controller.stream.frames) <= 8400
                    except Exception as exc:
                        failures += 1
                        errors.append({'elapsed_seconds': round(time.perf_counter() - started, 3),
                                       'phase': 'HTTP poll', 'type': type(exc).__name__})
                    duration = time.perf_counter() - tick
                    poll_samples.append(duration)
                    max_poll_seconds = max(max_poll_seconds, duration)
                    next_poll = max(next_poll + .5, time.perf_counter())
                    if time.perf_counter() >= next_checkpoint:
                        write_report('running')
                        next_checkpoint = time.perf_counter() + args.checkpoint_seconds
                request('/command/disconnect', {})
                state = request('/state')
                assert not state['connected'] and state['waveform'] is None
                assert state['recognition']['result'] is None
                assert saved_checks > 0, 'capture did not complete'
                write_report('PASS' if failures == 0 else 'FAIL')
            finally:
                if server is not None:
                    server.shutdown()
                    server.server_close()
                if server_thread is not None:
                    server_thread.join(timeout=5)
                if controller is not None:
                    controller.close()
                    result['cleanup'] = {'worker_stopped': not controller.worker.is_alive(),
                                         'stream_stopped': not (controller.stream.thread and controller.stream.thread.is_alive())}
        result['cleanup']['temporary_data_removed'] = not Path(folder).exists()
        output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    except Exception as exc:
        result.update(status='FAIL', fatal_error=type(exc).__name__)
        output.write_text(json.dumps(result, indent=2), encoding='utf-8')
        raise
    print(json.dumps({'status': result['status'], 'elapsed_seconds': result['latest']['elapsed_seconds'],
                      'http_polls': polls, 'http_failures': failures, 'cleanup': result['cleanup']}))
    if result['status'] != 'PASS':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
