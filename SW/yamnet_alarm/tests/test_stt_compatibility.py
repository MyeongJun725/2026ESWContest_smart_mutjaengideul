import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

source = Path(__file__).parents[2] / "local_stt"
sys.path.insert(0, str(source))
spec = importlib.util.spec_from_file_location(
    "stt_server_under_test", source / "server.py"
)
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


class Session:
    epoch = 0

    def accept(self, pcm):
        return dict(type="ack", bytes=len(pcm), epoch=self.epoch)

    def reset(self, epoch):
        self.epoch = epoch


class Recognizer:
    def session(self):
        return Session()


class SttCompatibilityTests(unittest.TestCase):
    def test_missing_detector_never_changes_stt_ack_or_reset_protocol(self):
        with patch.object(
            server, "AudioTap", side_effect=OSError("optional tap absent")
        ):
            with TestClient(server.create_app(factory=Recognizer)) as client:
                with client.websocket_connect("/stt/stream") as socket:
                    self.assertEqual(
                        socket.receive_json(),
                        dict(type="ready", protocol="safehub.pcm.v1"),
                    )
                    socket.send_bytes(b"\0" * 3200)
                    self.assertEqual(
                        socket.receive_json(), dict(type="ack", bytes=3200, epoch=0)
                    )
                    socket.send_json(dict(type="reset", epoch=7))
                    self.assertEqual(socket.receive_json(), dict(type="reset", epoch=7))
                with client.websocket_connect("/stt/stream") as socket:
                    self.assertEqual(socket.receive_json()["type"], "ready")

    def test_optional_tap_gets_original_pcm_before_stt(self):
        with patch.object(server, "AudioTap") as create:
            with TestClient(server.create_app(factory=Recognizer)) as client:
                with client.websocket_connect("/stt/stream") as socket:
                    socket.receive_json()
                    pcm = b"\x01\x02" * 1600
                    socket.send_bytes(pcm)
                    self.assertEqual(socket.receive_json()["bytes"], len(pcm))
                    create.return_value.offer.assert_called_once_with(pcm, 0)
            create.return_value.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
