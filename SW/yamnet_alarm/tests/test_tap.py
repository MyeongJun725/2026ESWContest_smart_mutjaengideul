from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[2] / "local_stt"))
from safehub_audio_tap import AudioTap, HEADER


class TapTests(unittest.TestCase):
    @patch("safehub_audio_tap.socket.AF_UNIX", 1, create=True)
    @patch("safehub_audio_tap.socket.socket")
    def test_optional_failure_returns_immediately_and_backs_off(self, create):
        create.return_value.sendto.side_effect = OSError("not installed")
        tap = AudioTap()
        self.assertFalse(tap.offer(b"\0" * 3200))
        self.assertFalse(tap.offer(b"\0" * 3200))
        create.return_value.sendto.assert_called_once()
        create.return_value.setblocking.assert_called_once_with(False)

    @patch("safehub_audio_tap.socket.AF_UNIX", 1, create=True)
    @patch("safehub_audio_tap.socket.socket")
    def test_pcm_preserved_and_sequence_epoch_visible(self, create):
        tap = AudioTap()
        pcm = b"\x01\x02" * 1600
        self.assertTrue(tap.offer(pcm, 7))
        packet = create.return_value.sendto.call_args.args[0]
        self.assertEqual(packet[HEADER.size :], pcm)
        self.assertEqual(HEADER.unpack_from(packet)[2:4], (7, 0))


if __name__ == "__main__":
    unittest.main()
