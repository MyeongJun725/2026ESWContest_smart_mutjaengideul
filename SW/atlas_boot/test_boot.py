"""Bootstrap tests use a stub only; never call the host's real systemctl."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class BootTests(unittest.TestCase):
    def run_boot(self, state="not-found", reload_fails=False, query_fails=False):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            calls = root / "calls"
            stub = root / "systemctl"
            stub.write_text(
                '#!/bin/sh\nprintf "%s\\n" "$*" >> "$SAFEHUB_TEST_CALLS"\n'
                'case "$1" in\n'
                'daemon-reload) exit "$SAFEHUB_TEST_RELOAD";;\n'
                'show) printf "%s\\n" "$SAFEHUB_TEST_STATE"; '
                'exit "$SAFEHUB_TEST_QUERY";;\nesac\n',
                encoding="utf-8",
            )
            stub.chmod(0o755)
            result = subprocess.run(
                ["sh", str(Path(__file__).with_name("boot.sh"))],
                env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                     "SAFEHUB_TEST_CALLS": str(calls), "SAFEHUB_TEST_STATE": state,
                     "SAFEHUB_TEST_RELOAD": str(int(reload_fails)),
                     "SAFEHUB_TEST_QUERY": str(int(query_fails))},
                capture_output=True, text=True, check=False,
            )
            return result.returncode, calls.read_text().splitlines()

    def test_installed_stt_starts_after_reload_and_base_services(self):
        code, calls = self.run_boot(state="loaded")
        self.assertEqual(code, 0)
        self.assertEqual(calls, [
            "daemon-reload",
            "--no-block start safehub-mqtt.service safehub-csi.service safehub-ui.service",
            "show --property=LoadState --value safehub-stt.service",
            "--no-block start safehub-stt.service",
        ])

    def test_external_server_configuration_needs_no_local_unit(self):
        code, calls = self.run_boot()
        self.assertEqual(code, 0)
        self.assertNotIn("--no-block start safehub-stt.service", calls)

    def test_failed_reload_prevents_start_and_unit_query(self):
        code, calls = self.run_boot(state="loaded", reload_fails=True)
        self.assertNotEqual(code, 0)
        self.assertEqual(calls, ["daemon-reload"])

    def test_failed_unit_lookup_does_not_start_stt(self):
        code, calls = self.run_boot(query_fails=True)
        self.assertEqual(code, 0)
        self.assertNotIn("--no-block start safehub-stt.service", calls)


if __name__ == "__main__":
    unittest.main(verbosity=2)
