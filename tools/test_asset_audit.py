"""Flutter permits both file and directory asset entries."""
from pathlib import Path
import tempfile
import unittest
from audit_product_sources import audit


class AssetAuditTests(unittest.TestCase):
    def test_directory_entry_exists_but_missing_directory_is_reported(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder)
            (source / "lib").mkdir()
            (source / "lib/main.dart").write_text("void main() {}")
            (source / "assets/audio").mkdir(parents=True)
            (source / "assets/audio/clip.mp3").write_bytes(b"fixture")
            (source / "pubspec.yaml").write_text(
                "flutter:\n  assets:\n    - assets/audio/\n    - assets/missing/\n"
            )
            self.assertEqual(audit(source)["missing_assets"], ["assets/missing/"])


if __name__ == "__main__":
    unittest.main()
