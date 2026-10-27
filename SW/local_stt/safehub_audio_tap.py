"""Best-effort local PCM copy. Never waits for or opens an audio device."""

import os
import socket
import struct
import time

HEADER = struct.Struct("<4sIIIQ")
MAGIC = b"YAM1"


class AudioTap:
    def __init__(self, path=None):
        if not hasattr(socket, "AF_UNIX"):
            raise OSError("Optional local audio tap requires Unix sockets")
        self.path = path or os.getenv(
            "YAMNET_AUDIO_SOCKET", "/run/safehub-yamnet/audio.sock"
        )
        self.session = int.from_bytes(os.urandom(4), "little")
        self.sequence = 0
        self.retry_at = 0.0
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.socket.setblocking(False)

    def offer(self, pcm, epoch=0):
        sequence = self.sequence
        self.sequence = (sequence + 1) & 0xFFFFFFFF
        if time.monotonic() < self.retry_at:
            return False
        try:
            header = HEADER.pack(
                MAGIC, self.session, epoch & 0xFFFFFFFF, sequence, time.monotonic_ns()
            )
            self.socket.sendto(header + pcm, self.path)
            return True
        except (OSError, ValueError, OverflowError, struct.error):
            # Failure of the optional detector must never delay captions.
            self.retry_at = time.monotonic() + 0.5
            return False

    def close(self):
        self.socket.close()
