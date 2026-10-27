from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parents[1]))
from pcm_stream import HEADER, PcmWindows


class PcmTests(unittest.TestCase):
    def packet(self, sequence, stamp, epoch=0):
        return HEADER.pack(b"YAM1", 1, epoch, sequence, stamp) + b"\0" * 3200

    def test_window_uses_only_observed_samples(self):
        stream = PcmWindows()
        for n in range(9):
            self.assertIsNone(
                stream.accept(self.packet(n, n * 100_000_000), n * 100_000_000)
            )
        self.assertEqual(
            len(stream.accept(self.packet(9, 900_000_000), 900_000_000)), 31200
        )

    def test_missing_or_stale_packet_clears_partial_observation(self):
        stream = PcmWindows()
        stream.accept(self.packet(0, 0), 0)
        stream.accept(self.packet(2, 200_000_000), 200_000_000)
        self.assertEqual(len(stream.buffer), 3200)
        stream.accept(self.packet(3, 300_000_000), 900_000_000)
        self.assertEqual(len(stream.buffer), 0)

    def test_epoch_reset_cannot_mix_utterances(self):
        stream = PcmWindows()
        stream.accept(self.packet(0, 0), 0)
        stream.accept(self.packet(1, 100_000_000, epoch=1), 100_000_000)
        self.assertEqual(len(stream.buffer), 3200)


if __name__ == "__main__":
    unittest.main()
