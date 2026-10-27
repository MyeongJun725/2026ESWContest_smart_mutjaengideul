"""Product CSI permits inference controls, never capture/training/data edits."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bridge import Controller, main

class ProductScopeTests(unittest.TestCase):
    def test_inference_only_rejects_development_commands_before_side_effects(self):
        with tempfile.TemporaryDirectory() as folder:
            app = Controller(folder, inference_only=True)
            try:
                for action in ('capture','cancel_capture','train','import_model','export_model',
                               'delete_records','restore_records','add_behavior',
                               'remove_behavior','import_records','export_records'):
                    with self.subTest(action=action):
                        with self.assertRaisesRegex(ValueError, '상태·추론 전용'):
                            app.command(action,{})
                self.assertIsNone(app.capture)
                self.assertEqual(app.training, {'state':'idle'})
                self.assertFalse(app.allow_training)
                with patch.object(app, 'models', return_value=[{'model_id':'existing-trained-model'}]):
                    self.assertEqual(app.command('select_model', {'id':'existing-trained-model'}), {'ok':True})
                self.assertEqual(app.model['model_id'], 'existing-trained-model')
                self.assertEqual(app.command('stop_recognition',{}),{'ok':True})
                self.assertEqual(app.command('disconnect',{}),{'ok':True})
            finally:
                app.close()

    def test_closed_controller_storage_is_not_reused_for_next_root(self):
        with tempfile.TemporaryDirectory() as first:
            app = Controller(first, inference_only=True)
            app.close()
        with tempfile.TemporaryDirectory() as second:
            app = Controller(second, inference_only=True)
            try:
                app.command('stop_recognition', {})
                self.assertEqual(app.db.DATA, Path(second).resolve())
                self.assertTrue((Path(second) / 'workspace.json').is_file())
            finally:
                app.close()

    def test_cli_rejects_training_in_product_mode_before_starting(self):
        with patch('sys.argv', ['bridge.py', '--inference-only', '--allow-training']), patch('bridge.Controller') as controller:
            with self.assertRaises(SystemExit) as error:
                main()
            self.assertEqual(error.exception.code, 2)
            controller.assert_not_called()

if __name__ == '__main__':
    unittest.main()
