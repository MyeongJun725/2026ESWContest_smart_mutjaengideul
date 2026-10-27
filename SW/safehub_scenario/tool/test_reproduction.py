"""Exercise source packaging without Flutter, ATLAS services or hardware."""

import json
import hashlib
from pathlib import Path
import re
import shutil
import sys
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]
REPO = SOURCE.parents[1]


class ReproductionTests(unittest.TestCase):
    def test_manifest_cmake_pubspec_and_launcher_agree_on_identity(self):
        app_id = "com.atlas.app.safehub_scenario_pr7"
        manifest = json.loads((SOURCE / "atlas/meta/appinfo.json").read_text())
        version = re.search(r"^version: (\S+)", (SOURCE / "pubspec.yaml").read_text(), re.M)[1]
        self.assertEqual(manifest["id"], app_id)
        self.assertEqual(manifest["version"], version.split("+")[0])
        self.assertEqual(manifest["entry"], f"safehub_app --bundle=./ --fullscreen -a {app_id}")
        self.assertIn(f'set(ATLAS_APP_ID "{app_id}")', (SOURCE / "atlas/CMakeLists.txt").read_text())
        for name in ("start-ui.sh", "install-bootstrap.sh"):
            self.assertIn(app_id, (REPO / "SW/atlas_boot" / name).read_text())

    def test_distributed_assets_keep_reviewed_license_notices(self):
        sources = json.loads((SOURCE / "THIRD_PARTY_SOURCES.json").read_text())
        for item in sources:
            path = SOURCE / item['file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), item['sha256'])
        self.assertIn('assets/fonts/OFL.txt', (SOURCE / 'pubspec.yaml').read_text())
        self.assertIn('flutter-embedded-linux-LICENSE.txt', (SOURCE / 'atlas/CMakeLists.txt').read_text())

    def test_new_dart_and_plugin_sources_are_not_ignored(self):
        for relative in ("lib/new_feature.dart", "third_party/record_atlas/lib/new_feature.dart"):
            result = subprocess.run(["git", "check-ignore", "-q", str(SOURCE / relative)],
                                    cwd=REPO, capture_output=True)
            self.assertEqual(result.returncode, 1, relative)

    def test_host_contains_exact_scenario_sources_tests_and_assets(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "host"
            subprocess.run(["python3", str(SOURCE / "tool/prepare_host_tests.py"), str(output)],
                           check=True, capture_output=True)
            for directory in ("lib", "test", "assets"):
                for original in (SOURCE / directory).rglob("*"):
                    if original.is_file():
                        self.assertEqual(original.read_bytes(), (output / original.relative_to(SOURCE)).read_bytes())
            pubspec = (output / "pubspec.yaml").read_text()
            self.assertNotIn("audioplayers_atlas:", pubspec)
            self.assertNotIn("record_atlas:", pubspec)
            self.assertIn("name: safehub_app", pubspec)
            self.assertEqual((output / "pubspec.lock").read_bytes(),
                             (SOURCE / "tool/host_pubspec.lock").read_bytes())
            marker = output / "user-file"
            marker.write_text("preserve me")
            again = subprocess.run(["python3", str(SOURCE / "tool/prepare_host_tests.py"), str(output)],
                                   capture_output=True)
            self.assertNotEqual(again.returncode, 0)
            self.assertEqual(marker.read_text(), "preserve me")


    def test_scenario_tools_work_without_legacy_ui_or_csi_checkout(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            isolated = root / "repo/SW/safehub_scenario"
            shutil.copytree(SOURCE, isolated, ignore=shutil.ignore_patterns(
                "build", ".dart_tool", "__pycache__"))
            self.assertFalse((isolated.parent / "safehub_app").exists())
            self.assertFalse((isolated.parent / "wifi_sensing").exists())
            # Both real packaging entry points must work in this reduced tree.
            subprocess.run([sys.executable, str(isolated / "tool/prepare_host_tests.py"),
                            str(root / "host")], check=True, capture_output=True)
            subprocess.run([sys.executable, str(isolated / "tool/run_ui_preview.py"),
                            "--check-only"], check=True, capture_output=True)
            self.assertEqual((root / "host/lib/main.dart").read_bytes(),
                             (SOURCE / "lib/main.dart").read_bytes())

    def test_host_output_cannot_enter_another_repository_directory(self):
        # A nonexistent child must be rejected without creating tracked/local files.
        output = REPO / "SW" / "cleanup-test-output-do-not-create"
        self.assertFalse(output.exists())
        result = subprocess.run([sys.executable, str(SOURCE / "tool/prepare_host_tests.py"),
                                 str(output)], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
