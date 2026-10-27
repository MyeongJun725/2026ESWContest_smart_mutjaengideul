"""Reject missing/stale PCM; never synthesize samples to fill an observation."""

import struct
import time

HEADER = struct.Struct("<4sIIIQ")
WINDOW = 15600
HOP = 7680


class PcmWindows:
    def __init__(self):
        self.buffer = bytearray()
        self.session = self.sequence = self.last_ns = None
        self.samples = self.emitted = 0
        self.generation = 0

    def reset(self):
        self.buffer.clear()
        self.samples = self.emitted = 0
        self.generation += 1

    def accept(self, packet, now_ns=None):
        now_ns = time.monotonic_ns() if now_ns is None else now_ns
        if len(packet) <= HEADER.size:
            return None
        magic, session, epoch, sequence, stamp = HEADER.unpack_from(packet)
        pcm = packet[HEADER.size :]
        if magic != b"YAM1" or len(pcm) % 2 or len(pcm) > 6400:
            return None
        if not 0 <= now_ns - stamp <= 400_000_000:
            self.reset()
            return None
        identity = (session, epoch)
        if (
            identity != self.session
            or self.sequence is None
            or sequence != (self.sequence + 1) & 0xFFFFFFFF
            or self.last_ns is None
            or stamp - self.last_ns > 600_000_000
        ):
            self.reset()
        self.session, self.sequence, self.last_ns = identity, sequence, stamp
        self.samples += len(pcm) // 2
        self.buffer.extend(pcm)
        del self.buffer[: -WINDOW * 2]
        if len(self.buffer) < WINDOW * 2:
            return None
        if self.emitted and self.samples - self.emitted < HOP:
            return None
        self.emitted = self.samples
        return bytes(self.buffer)
