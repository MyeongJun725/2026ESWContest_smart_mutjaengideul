"""The source-check runner must stop network calls before touching a broker."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('hub_checks', Path(__file__).with_name('run_hub_checks.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class HubCheckRunnerTests(unittest.TestCase):
    def test_network_attempt_is_blocked_before_script_continues(self):
        with tempfile.TemporaryDirectory() as folder:
            script = Path(folder) / 'probe.py'
            marker = Path(folder) / 'should-not-exist'
            script.write_text('import socket\nfrom pathlib import Path\n'
                              'socket.create_connection(("127.0.0.1", 9))\n'
                              f'Path({str(marker)!r}).write_text("unexpected")\n')
            with self.assertRaises(subprocess.CalledProcessError) as error:
                runner.run_script(script, capture_output=True, text=True)
            self.assertIn('network connections are disabled', error.exception.stderr)
            self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main()
