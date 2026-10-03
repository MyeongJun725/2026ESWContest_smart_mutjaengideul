"""Synthetic integration evidence only; does not measure action accuracy."""

import hashlib
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch
import urllib.error
import urllib.request
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bridge import Controller, Handler, RUNTIME, main


class IntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.app = Controller(cls.temp.name, allow_training=True)
        cls.app.stop_event.set()
        cls.app.worker.join()
        import torch
        torch.set_num_threads(1)

    @classmethod
    def tearDownClass(cls):
        cls.app.close()
        cls.temp.cleanup()

    def setUp(self):
        self.app.stream.stop()
        self.app.recognition.stop()
        self.app.capture = None
        self.app.model = self.app.bundle = None
        self.app.training = {'state': 'idle'}
        self.app.allow_training = True
        self.app.allow_dummy = True

    def frames(self, start=10, seconds=4):
        from stream import dummy_frame
        return [dict(dummy_frame(start + i / 60), device_t=start + i / 60)
                for i in range(int(seconds * 60) + 1)]

    def attach(self, frames):
        stream = self.app.stream
        stream.connected = True
        stream.mode = 'dummy'
        with stream.lock:
            stream.frames.extend(frames)

    def test_01_source_hashes_match_laptop_snapshot(self):
        manifest = json.loads((RUNTIME / 'LOCAL_SOURCE_MANIFEST.json').read_text())
        for filename, digest in manifest['files'].items():
            self.assertEqual(hashlib.sha256((RUNTIME / filename).read_bytes()).hexdigest(), digest)
        from soom_engine import verify_vendor
        self.assertEqual(len(verify_vendor()['files']), 6)

    def test_02_live_preview_equals_latest_engine_and_toggles(self):
        import numpy as np
        from signal_pipeline import latest_signal
        frames = self.frames()
        self.attach(frames)
        with patch.object(self.app.stream, 'now', return_value=14):
            shown = self.app.status()['waveform']['signal']
            expected = latest_signal(frames, 'raw_iq_52', 4)['signal']
            self.assertTrue(np.array_equal(shown, expected))
            raw = self.app.status(dict(denoise=False, normalize=False, pca=False, lowpass=False))['waveform']['signal']
            self.assertFalse(np.array_equal(shown, raw))
            self.assertEqual(len(raw), 240)

    def test_03_capture_saves_and_batch_delete_restores(self):
        stream = self.app.stream
        self.attach(self.frames(0))
        with patch.object(stream, 'now', return_value=4):
            self.app.command('capture', {'label': '정지', 'seconds': 8, 'round': 'round-a'})
        self.attach(self.frames(7, 8))
        with patch.object(stream, 'now', return_value=15):
            self.app._advance()
        self.assertTrue(self.app.capture_saved)
        self.assertEqual(len(self.app.db.CACHE), 0)
        record = self.app.records()[-1]
        self.assertEqual(record['collection']['mode'], 'dummy')
        ids = [record['id']]
        self.app.command('delete_records', {'ids': ids})
        self.assertFalse(any(r['id'] in ids for r in self.app.records()))
        self.app.command('restore_records', {'ids': ids})
        self.assertTrue(any(r['id'] in ids for r in self.app.records()))

    def test_04_gap_clears_waveform_prediction_and_cancels_capture(self):
        self.attach(self.frames())
        with patch.object(self.app.stream, 'now', return_value=14):
            self.app.command('capture', {'label': '정지', 'seconds': 8, 'round': 'gap'})
        self.app.recognition.result = {'label': '낙상', 'score': .99}
        with patch.object(self.app.stream, 'now', return_value=16):
            self.app._advance()
            state = self.app.status()
        self.assertIsNone(state['waveform'])
        self.assertIsNone(state['recognition']['result'])
        self.assertEqual(self.app.capture.state, 'failed')

    def test_05_reconnect_cannot_finish_old_capture(self):
        self.attach(self.frames())
        with patch.object(self.app.stream, 'now', return_value=14):
            self.app.command('capture', {'label': '정지', 'seconds': 8, 'round': 'reset'})
        self.app.stream.reset()
        self.attach(self.frames(20))
        with patch.object(self.app.stream, 'now', return_value=24):
            self.app._advance()
        self.assertEqual(self.app.capture.state, 'failed')

    def test_06_selected_training_export_and_portable_inference(self):
        import numpy as np
        from signal_pipeline import latest_signal
        from edge_runtime import infer, load_bundle
        records = []
        for group in range(3):
            for label in ('합성 A', '합성 B'):
                sid = uuid.uuid4().hex
                record = dict(id=sid, source_id=sid, experiment_id=f'round-{group}',
                              label=label, name=label, representation='raw_iq_52',
                              frames=self.frames(10 + group * 8),
                              collection=dict(mode='dummy', hardware='synthetic'))
                self.app.db.write_json(self.app.db.SEGMENTS / f'{sid}.json', record)
                records.append(record)
        self.app._fit(records)
        self.assertEqual(self.app.training['state'], 'complete', self.app.training)
        model = self.app.model
        self.assertEqual(set(model['segment_ids']), {r['id'] for r in records})
        with np.load(self.app.db.MODELS / model['processed_signals_file'], allow_pickle=False) as audit:
            groups = [set(audit['groups'][audit['split'] == split]) for split in ('train', 'validation', 'test')]
            self.assertTrue(all(not groups[i] & groups[j] for i in range(3) for j in range(i)))
            index = int(np.flatnonzero(audit['record_ids'] == records[0]['id'])[0])
            expected = latest_signal(records[0]['frames'], 'raw_iq_52', 4)['components']
            np.testing.assert_allclose(audit['signals'][index], np.asarray(expected).T, atol=1e-5)
        import zipfile
        exported = self.app.command('export_model', {})['path']
        folder = Path(self.temp.name) / 'portable'
        with zipfile.ZipFile(exported) as archive:
            archive.extractall(folder)
        bundle = load_bundle(folder / 'model')
        python_result = self.app.teaching.predict_frames(model, records[0]['frames'], 'raw_iq_52')
        portable_result = infer(records[0]['frames'], bundle)
        np.testing.assert_allclose(list(python_result['scores'].values()), list(portable_result['scores'].values()), atol=1e-5)
        self.app.command('import_model', {'path': str(folder / 'model')})
        self.assertIsNotNone(self.app.bundle)
        self.assertEqual(self.app.model['feature_profile'], self.app.profile)

    def test_07_pi_rejects_training_and_dummy_live_models_cannot_mix(self):
        self.app.allow_training = False
        with self.assertRaisesRegex(ValueError, 'PC'):
            self.app.command('train', {'ids': []})
        self.app.model = {'model_id': 'abc', 'collection': {'mode': 'live', 'hardware': 'c6_ht20_soom_input'}}
        self.attach(self.frames())
        with patch.object(self.app.stream, 'now', return_value=14):
            with self.assertRaisesRegex(ValueError, '모의/실측'):
                self.app.command('recognize', {})
        records = self.app.records()
        self.assertFalse(self.app.services.selection_state([
            records[0], dict(records[0], collection={'mode': 'live', 'hardware': 'c6_ht20_soom_input'})], 4)[0])

    def test_08_http_contract_and_browser_mutation_rejection(self):
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        server.controller = self.app
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f'http://127.0.0.1:{server.server_port}'
        try:
            with urllib.request.urlopen(base + '/state') as response:
                self.assertEqual(json.load(response)['profile'], self.app.profile)
            request = urllib.request.Request(base + '/command/add_behavior', data=b'{"name":"demo"}', headers={'Content-Type': 'application/json'})
            with urllib.request.urlopen(request) as response:
                self.assertTrue(json.load(response)['ok'])
            request.add_header('Origin', 'http://example.com')
            with self.assertRaises(urllib.error.HTTPError) as error:
                urllib.request.urlopen(request)
            self.assertEqual(error.exception.code, 403)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_09_polling_uses_metadata_cache_and_buffer_is_bounded(self):
        from stream import dummy_frame
        self.app.record_summaries()
        with patch.object(Path, 'read_text', side_effect=AssertionError('raw files reread')):
            self.assertTrue(self.app.record_summaries())
        frame = dummy_frame(10)
        for _ in range(9000):
            self.app.stream._append(frame)
        self.assertEqual(len(self.app.stream.frames), 8400)

    def test_10_disconnecting_during_preprocessing_cannot_show_old_waveform(self):
        from signal_pipeline import latest_signal
        self.attach(self.frames())
        def disconnect(*args, **kwargs):
            result = latest_signal(*args, **kwargs)
            self.app.stream.stop()
            return result
        with patch.object(self.app.stream, 'now', return_value=14):
            with patch('signal_pipeline.latest_signal', side_effect=disconnect):
                state = self.app.status()
        self.assertIsNone(state['waveform'])
        self.assertFalse(state['fresh'])

    def test_11_real_only_rejects_dummy_without_interrupting_current_input(self):
        self.app.allow_dummy = False
        self.app.capture = Mock(state='recording')
        previous = self.app.stream.snapshot()
        with patch.object(self.app.stream, 'start') as start:
            with patch.object(self.app.recognition, 'stop') as stop:
                with self.assertRaisesRegex(ValueError, '실제 장비 연결 모드'):
                    self.app.command('connect', {'mode': 'dummy'})
                start.assert_not_called()
                stop.assert_not_called()
        self.app.capture.cancel.assert_not_called()
        self.assertEqual(self.app.stream.snapshot()['session'], previous['session'])
        self.assertEqual(self.app.stream.snapshot()['epoch'], previous['epoch'])
        self.app.capture = None
        self.assertFalse(self.app.status()['dummy_allowed'])

    def test_12_real_only_keeps_serial_connect_path(self):
        self.app.allow_dummy = False
        with patch.object(self.app.stream, 'start') as start:
            self.app.command('connect', {'mode': 'live', 'port': 'TEST_PORT',
                                         'baud': 921600})
        start.assert_called_once_with('live', 'TEST_PORT', 921600)

    def test_13_cli_real_only_flag_and_compatible_default(self):
        for flag, allowed in [([], True), (['--real-only'], False)]:
            with self.subTest(real_only=not allowed):
                with patch('sys.argv', ['bridge.py', '--data-dir', self.temp.name] + flag):
                    with patch('bridge.Controller') as controller:
                        with patch('bridge.ThreadingHTTPServer') as server:
                            server.return_value.serve_forever.side_effect = KeyboardInterrupt
                            main()
                        controller.assert_called_once_with(Path(self.temp.name), False,
                                                           allow_dummy=allowed)
                        controller.return_value.close.assert_called_once()

    def test_14_real_only_http_rejects_synthetic_request(self):
        self.app.allow_dummy = False
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        server.controller = self.app
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f'http://127.0.0.1:{server.server_port}'
        try:
            with urllib.request.urlopen(base + '/state') as response:
                self.assertFalse(json.load(response)['dummy_allowed'])
            request = urllib.request.Request(base + '/command/connect',
                                             data=b'{"mode":"dummy"}',
                                             headers={'Content-Type': 'application/json'})
            with self.assertRaises(urllib.error.HTTPError) as error:
                urllib.request.urlopen(request)
            self.assertEqual(error.exception.code, 400)
            self.assertIn('실제 장비 연결 모드', json.load(error.exception)['error'])
            self.assertFalse(self.app.stream.snapshot()['connected'])
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == '__main__':
    unittest.main(verbosity=2)
