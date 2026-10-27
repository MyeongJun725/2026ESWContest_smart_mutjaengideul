import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

path=Path(__file__).parents[1]/"tools/sign_capture_diagnostics.py"
spec=importlib.util.spec_from_file_location("diagnostics",path)
diagnostics=importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnostics)


class CaptureTests(unittest.TestCase):
    def test_numeric_maximum(self):
        rows=[{"processing_ms":value} for value in [99,"474",598,"814",1415,"nan",None]]
        self.assertEqual(diagnostics.processing_summary(rows),
                         {"measured_frames":5,"max_processing_ms":1415.0})

    def test_actual_stderr_not_hardcoded(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/"42").mkdir()
            actual=root/"tracking-roi-retry-v1.log";actual.write_text("actual")
            (root/"42/cmdline").write_bytes(b"/data/safehub/vision_stream_sign_live_mqtt_rpi4\0"+
                b"640\0"+b"480\0/models\0/data/safehub/logs/current.jsonl\0")
            with patch.object(diagnostics.os,"readlink",return_value=str(actual)):
                json_path,stderr=diagnostics.process_paths(42,root)
            self.assertEqual(stderr,actual)
            self.assertEqual(json_path.name,"current.jsonl")

    def test_truncation_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/"log";path.write_text("before")
            before=diagnostics.mark(path);path.write_text("")
            with self.assertRaises(RuntimeError):diagnostics.read_new(path,before)


if __name__=="__main__":unittest.main()
