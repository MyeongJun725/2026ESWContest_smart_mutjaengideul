"""Check Windows preparation boundaries without launching Flutter or hardware."""
from pathlib import Path
import tempfile
import unittest

import prepare_windows_preview as preview


class WindowsPreparationTests(unittest.TestCase):
    def test_new_external_host_uses_current_ui_dependencies(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            flutter = root / 'flutter.bat'
            flutter.write_text('fixture; not executed')
            output = root / 'host'
            _, target, pubspec = preview.preflight(flutter, output)
            self.assertEqual(target, output)
            source_version = next(line for line in (preview.SOURCE / 'pubspec.yaml').read_text(encoding='utf-8').splitlines() if line.startswith('version:'))
            self.assertIn(source_version, pubspec)
            self.assertIn('mqtt_client: 10.5.1', pubspec)
            self.assertNotIn('audioplayers_atlas:', pubspec)
            self.assertNotIn('record_atlas:', pubspec)
            self.assertFalse(output.exists())

    def test_all_checkout_outputs_and_existing_user_folders_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            flutter = root / 'flutter.bat'
            flutter.write_text('fixture; not executed')
            marker = root / 'preserve.txt'
            marker.write_text('keep')
            with self.assertRaises(ValueError):
                preview.preflight(flutter, root)
            repository = preview.SOURCE.parents[1]
            output = repository / 'SW/windows_preview/do-not-create'
            with self.assertRaises(ValueError):
                preview.preflight(flutter, output)
            self.assertFalse(output.exists())
            self.assertEqual(marker.read_text(), 'keep')


if __name__ == '__main__':
    unittest.main()
