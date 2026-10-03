"""Local SafeHub control API around the unchanged latest laptop CSI engine."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import sys
import threading
import time
from urllib.parse import parse_qs, urlparse
import uuid

RUNTIME = Path(__file__).resolve().parent / 'runtime'
sys.path.insert(0, str(RUNTIME))


class Controller:
    def __init__(self, data_dir, allow_training=False, allow_dummy=True):
        # Configure isolated storage before the unchanged engine is imported.
        os.environ['WIFI_SENSING2_DATA_DIR'] = str(Path(data_dir).resolve())
        import server
        import services
        import teaching
        from stream import Stream
        from recognition import Recognition
        from soom_processing import PROFILE
        self.db, self.services, self.teaching = server, services, teaching
        self.profile = PROFILE
        self.stream = Stream()
        self.allow_dummy = allow_dummy
        if not allow_dummy:
            self.stream.error = 'ESP32 수신기를 연결하고 USB 포트를 선택하세요.'
        self.recognition = Recognition()
        self.lock = threading.RLock()
        self.allow_training = allow_training
        self.capture = None
        self.capture_key = None
        self.capture_saved = False
        self.training = {'state': 'idle'}
        self.record_index = {}
        self.model = None
        self.bundle = None
        self.pool = ThreadPoolExecutor(max_workers=2)
        self.predicting = False
        self.last_predict = 0
        self.stop_event = threading.Event()
        self.worker = threading.Thread(target=self._run, daemon=True)
        self.worker.start()

    def close(self):
        self.stop_event.set()
        self.worker.join(timeout=2)
        self.stream.stop()
        self.pool.shutdown(wait=True, cancel_futures=True)

    def records(self):
        return self.db.saved_segments()

    def record_summaries(self):
        # Polling must not reread every full I/Q file twice a second on Pi.
        paths = list(self.db.SEGMENTS.glob('*.json'))
        current = {path.stem for path in paths}
        for sid in list(self.record_index):
            if sid not in current:
                del self.record_index[sid]
        for path in paths:
            stat = path.stat()
            key = stat.st_mtime_ns, stat.st_size
            if self.record_index.get(path.stem, (None,))[0] != key:
                record = json.loads(path.read_text(encoding='utf-8'))
                self.record_index[path.stem] = key, self.db.summary(record)
        return [entry[1] for _, entry in sorted(self.record_index.items())]

    @staticmethod
    def model_summary(model):
        if model is None:
            return None
        return {key: model.get(key) for key in (
            'model_id', 'name', 'labels', 'balanced_accuracy', 'collection',
            'feature_profile', 'window_seconds',
        )}

    def models(self):
        result = []
        for path in self.db.MODELS.glob('*.json'):
            metadata = json.loads(path.read_text(encoding='utf-8'))
            if metadata.get('feature_profile') == self.profile:
                result.append(metadata)
        return result

    def _advance(self):
        state = self.stream.snapshot()
        now = self.stream.now()
        frames = state['frames']
        with self.lock:
            if self.capture and self.capture.state in ('preparing', 'recording'):
                valid = (state['fresh'] and self.capture_key ==
                         (state['session'], state['epoch']))
                self.capture.update(now, frames, valid)
                if self.capture.state == 'complete' and not self.capture_saved:
                    try:
                        saved = self.teaching.save_capture(self.capture)
                        # The desktop engine caches complete sessions for editing;
                        # this service retains only the current capture.
                        self.db.CACHE.pop(saved['source_id'], None)
                        self.capture_saved = True
                    except (OSError, ValueError) as exc:
                        self.capture.state, self.capture.error = 'failed', str(exc)
            recog = self.recognition
            if not recog.observe(state['connected'], state['session'], state['epoch'],
                                 frames[-1]['t'] if frames else None, now):
                return
            recent = [f for f in frames if f['t'] >= recog.start]
            if (self.predicting or now - self.last_predict < 3
                    or not recent or recent[-1]['t'] - recent[0]['t'] < 3.975):
                return
            self.predicting = True
            self.last_predict = now
            args = (recog.generation, self.model, self.bundle, recent, recent[-1]['t'])
            self.pool.submit(self._predict, *args)

    def _run(self):
        while not self.stop_event.wait(.1):
            try:
                self._advance()
            except Exception as exc:
                with self.lock:
                    self.recognition.clear(f'처리 오류: {exc}')

    def _predict(self, generation, model, bundle, frames, end):
        try:
            if bundle:
                from edge_runtime import infer
                result = infer(frames, bundle)
                result['score'] = max(result['scores'].values())
            else:
                result = self.teaching.predict_frames(model, frames, 'raw_iq_52')
                result.pop('input_signal', None)
            with self.lock:
                self.recognition.accept(generation, model['model_id'], result,
                                        end, self.stream.now())
        except Exception as exc:
            with self.lock:
                if self.recognition.generation == generation:
                    self.recognition.clear(str(exc))
        finally:
            self.predicting = False

    def status(self, options=None):
        from signal_pipeline import latest_signal
        from core import estimate_rate
        state = self.stream.snapshot()
        frames = state.pop('frames')
        waveform = None
        reason = '새 신호 대기'
        if frames:
            try:
                waveform = latest_signal(frames, 'raw_iq_52', 4, options)
            except ValueError as exc:
                reason = str(exc)
        # No response may expose a previous result after a disconnect/gap.
        latest = self.stream.snapshot()
        if (not latest['fresh'] or
                (latest['session'], latest['epoch']) != (state['session'], state['epoch'])):
            waveform = None
            frames = []
            reason = '새 신호 대기'
            state = {k: v for k, v in latest.items() if k != 'frames'}
        with self.lock:
            if not state['fresh']:
                self.recognition.clear('새 신호 대기 · 이전 결과를 지웠습니다.')
            capture = self.capture
            settings = self.services.load_settings()
            return dict(
                **state, profile=self.profile, waveform=waveform,
                waveform_reason=reason, rate_hz=estimate_rate(frames) if frames else 0,
                behaviors=list(self.services.DEFAULT_BEHAVIORS) + self.services.custom_behaviors(settings),
                records=self.record_summaries(),
                models=[self.model_summary(m) for m in self.models()],
                model=self.model_summary(self.model), training=self.training,
                training_allowed=self.allow_training,
                dummy_allowed=self.allow_dummy,
                recognition={'running': self.recognition.running,
                             'result': self.recognition.result,
                             'reason': self.recognition.reason},
                capture=None if capture is None else {
                    'state': capture.state, 'label': capture.label,
                    'error': capture.error, 'saved': self.capture_saved,
                    'remaining': max(0, capture.end - self.stream.now()),
                },
            )

    def command(self, action, payload):
        with self.lock:
            if action == 'connect':
                if payload['mode'] == 'dummy' and not self.allow_dummy:
                    raise ValueError('실제 장비 연결 모드에서는 모의 신호를 사용할 수 없습니다.')
                self.recognition.stop()
                if self.capture:
                    self.capture.cancel()
                self.stream.start(payload['mode'], payload.get('port', ''), int(payload.get('baud', 921600)))
            elif action == 'disconnect':
                self.recognition.stop()
                if self.capture:
                    self.capture.cancel()
                self.stream.stop()
            elif action == 'capture':
                self._capture(payload)
            elif action == 'cancel_capture':
                if self.capture:
                    self.capture.cancel()
            elif action in ('add_behavior', 'remove_behavior'):
                name = self.services.behavior_name(payload['name'])
                settings = self.services.load_settings()
                names = self.services.custom_behaviors(settings)
                if name in self.services.DEFAULT_BEHAVIORS:
                    raise ValueError('정지와 낙상은 기본 행동으로 유지됩니다.')
                if action == 'add_behavior' and name not in names:
                    names.append(name)
                if action == 'remove_behavior' and name in names:
                    names.remove(name)
                self.services.save_settings(dict(settings, custom_behaviors=names))
            elif action in ('delete_records', 'restore_records'):
                if self.training['state'] == 'running':
                    raise ValueError('학습 완료 후 기록을 변경하세요.')
                from data_management import move_records
                move_records(payload['ids'], restore=action == 'restore_records')
            elif action == 'train':
                self._train(payload)
            elif action == 'select_model':
                model = next((m for m in self.models() if m['model_id'] == payload['id']), None)
                if model is None:
                    raise ValueError('모델을 찾을 수 없습니다.')
                from edge_runtime import load_bundle
                bundle_path = self.db.MODELS / model['model_id']
                bundle = load_bundle(bundle_path) if bundle_path.is_dir() else None
                self.recognition.stop()
                self.model, self.bundle = model, bundle
            elif action == 'recognize':
                self._recognize()
            elif action == 'stop_recognition':
                self.recognition.stop()
            elif action == 'import_records':
                self.services.import_records(payload['paths'])
            elif action == 'export_records':
                ids = set(payload['ids'])
                records = [r for r in self.records() if r['id'] in ids]
                if len(records) != len(ids):
                    raise ValueError('선택한 기록 목록이 변경되었습니다.')
                target = self.db.DATA / 'exports'
                target.mkdir(exist_ok=True)
                output = target / f'records-{uuid.uuid4().hex}.zip'
                self.services.export_records(records, output)
                return {'path': str(output)}
            elif action == 'import_model':
                self._import_model(Path(payload['path']))
            elif action == 'export_model':
                if not self.model or self.bundle:
                    raise ValueError('PC에서 학습한 모델을 먼저 선택하세요.')
                from edge_export import export_bundle
                target = self.db.DATA / 'exports'
                target.mkdir(exist_ok=True)
                output = target / (self.model['model_id'] + '.zip')
                export_bundle(self.model, output)
                return {'path': str(output)}
            else:
                raise ValueError('지원하지 않는 요청입니다.')
        return {'ok': True}

    def _capture(self, payload):
        if self.capture and self.capture.state in ('preparing', 'recording'):
            raise ValueError('이미 기록 중입니다.')
        state = self.stream.snapshot()
        if not state['fresh']:
            raise ValueError('새 신호가 들어온 뒤 기록하세요.')
        round_id = str(payload.get('round', '')).strip()[:120]
        if not round_id:
            raise ValueError('측정 회차를 입력하세요. 같은 실험은 같은 회차로 유지하세요.')
        context = dict(dataset='SafeHub', mode=state['mode'], hardware=state['hardware'], round_id=round_id)
        source = {'id': state['session'], 'representation': 'raw_iq_52'}
        self.capture = self.teaching.TimedCapture(
            source, self.services.behavior_name(payload['label']),
            float(payload['seconds']), 3, self.stream.now(), context,
        )
        self.capture_key = state['session'], state['epoch']
        self.capture_saved = False

    def _train(self, payload):
        if not self.allow_training:
            raise ValueError('이 기기는 수집·추론용입니다. PC에서 학습하세요.')
        if self.training['state'] == 'running':
            raise ValueError('학습이 이미 진행 중입니다.')
        ids = set(payload['ids'])
        records = [r for r in self.records() if r['id'] in ids]
        if len(records) != len(ids):
            raise ValueError('선택한 기록 목록이 변경되었습니다.')
        ready, reason = self.services.selection_state(records, 4)
        if not ready:
            raise ValueError(reason)
        self.recognition.stop('학습 중')
        self.training = {'state': 'running', 'count': len(records)}
        self.pool.submit(self._fit, records)

    def _fit(self, records):
        try:
            model = self.services.train_selected(records, 4, 'SafeHub 행동 모델')
            with self.lock:
                self.model, self.bundle = model, None
                self.training = {'state': 'complete', 'model_id': model['model_id']}
        except Exception as exc:
            with self.lock:
                self.training = {'state': 'failed', 'error': str(exc)}

    def _recognize(self):
        if not self.model:
            raise ValueError('학습하거나 가져온 모델을 선택하세요.')
        state = self.stream.snapshot()
        if not state['fresh']:
            raise ValueError('새 신호를 먼저 연결하세요.')
        expected = self.model['collection']
        if (expected['mode'], expected['hardware']) != (state['mode'], state['hardware']):
            raise ValueError('모의/실측 또는 보드 구성이 모델과 다릅니다.')
        self.recognition.begin(state['session'], state['epoch'], self.model['model_id'], self.stream.now())

    def _import_model(self, folder):
        from edge_runtime import load_bundle
        metadata, _, _ = load_bundle(folder)
        if metadata['representation'] != 'raw_iq_52' or metadata['window_seconds'] != 4:
            raise ValueError('현재 4초 CSI 모델이 아닙니다.')
        mid = uuid.uuid4().hex
        target = self.db.MODELS / mid
        target.mkdir()
        metadata = dict(metadata, model_id=mid, name=metadata.get('name', '가져온 모델'))
        self.db.write_json(target / 'model.json', metadata)
        shutil.copyfile(folder / 'weights.npz', target / 'weights.npz')
        bundle = load_bundle(target)
        self.db.write_json(self.db.MODELS / f'{mid}.json', metadata)
        self.recognition.stop()
        self.model, self.bundle = metadata, bundle


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, result, status=200):
        body = json.dumps(result, ensure_ascii=False, allow_nan=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        route = urlparse(self.path)
        try:
            if route.path == '/state':
                query = parse_qs(route.query)
                options = {key: query.get(key, ['true'])[0] == 'true'
                           for key in ('denoise', 'normalize', 'pca', 'lowpass')}
                options['subcarrier'] = max(0, min(51, int(query.get('subcarrier', ['0'])[0])))
                self.send_json(self.server.controller.status(options))
            elif route.path == '/ports':
                from serial.tools import list_ports
                self.send_json([{'port': p.device, 'name': p.description} for p in list_ports.comports()])
            else:
                self.send_json({'error': '없는 경로'}, 404)
        except (ValueError, OSError) as exc:
            self.send_json({'error': str(exc)}, 400)

    def do_POST(self):
        # Same-device native client only. Do not accept browser-origin requests.
        if self.headers.get('Origin') or not self.headers.get('Content-Type', '').startswith('application/json'):
            self.send_json({'error': '로컬 앱의 JSON 요청만 지원합니다.'}, 403)
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 65536:
                raise ValueError('요청 크기 오류')
            payload = json.loads(self.rfile.read(length))
            if not isinstance(payload, dict):
                raise ValueError('JSON 객체가 필요합니다.')
            action = self.path.removeprefix('/command/')
            self.send_json(self.server.controller.command(action, payload))
        except (ValueError, KeyError, TypeError, OSError) as exc:
            self.send_json({'error': str(exc)}, 400)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--data-dir', type=Path, default=Path.home() / 'SafeHubData' / 'csi')
    parser.add_argument('--allow-training', action='store_true')
    parser.add_argument('--real-only', action='store_true',
                        help='Disable synthetic input; only accept a real serial device.')
    args = parser.parse_args()
    controller = Controller(args.data_dir, args.allow_training,
                            allow_dummy=not args.real_only)
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    server.controller = controller
    print(f'SafeHub CSI ready: http://127.0.0.1:{args.port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        controller.close()


if __name__ == '__main__':
    main()
