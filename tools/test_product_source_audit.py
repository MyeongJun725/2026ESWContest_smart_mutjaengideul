"""Fault injection for cleanup checks; no SDK, network or device access."""
from pathlib import Path
import tempfile
import unittest

from audit_product_sources import audit


class ProductSourceAuditTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.source = Path(self.folder.name)
        (self.source / "lib").mkdir()
        (self.source / "pubspec.yaml").write_text("name: safehub_app\n")

    def write(self, name, text):
        path = self.source / "lib" / name
        path.write_text(text)

    def test_import_export_part_and_cycles_are_reachable(self):
        self.write("main.dart", "import 'package:safehub_app/view.dart';\n")
        self.write("view.dart", "export 'helper.dart';\npart 'part.dart';\n")
        self.write("helper.dart", "import 'view.dart';\n")
        self.write("part.dart", "part of 'view.dart';\n")
        report = audit(self.source)
        self.assertEqual(report["reachable_from_main"], 4)
        self.assertEqual(report["unreachable"], [])
        self.assertEqual(report["missing_local_imports"], [])

    def test_missing_local_import_is_reported(self):
        self.write("main.dart", "import 'removed.dart';\n")
        self.assertEqual(audit(self.source)["missing_local_imports"],
                         [{"file": "lib/main.dart", "uri": "removed.dart"}])

    def test_unused_widget_and_missing_asset_are_reported(self):
        self.write("main.dart", "void main() {}\n")
        self.write("old_widget.dart", "// unused UI\n")
        (self.source / "pubspec.yaml").write_text(
            "flutter:\n  assets:\n    - assets/missing.png\n")
        report = audit(self.source)
        self.assertEqual(report["unreachable"], ["lib/old_widget.dart"])
        self.assertEqual(report["missing_assets"], ["assets/missing.png"])

    def test_conditional_imports_keep_both_sources(self):
        self.write("main.dart", "import 'native.dart'\n if (dart.library.html) 'web.dart';\n")
        self.write("native.dart", "// native\n")
        self.write("web.dart", "// web\n")
        self.assertEqual(audit(self.source)["reachable_from_main"], 3)


if __name__ == "__main__":
    unittest.main()
