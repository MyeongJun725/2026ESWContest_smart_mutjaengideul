"""Real ASGI request validation with fake synthesis; no internet/device access."""
import asyncio
import importlib.util
from pathlib import Path
import unittest

from fastapi.testclient import TestClient

SPEC = importlib.util.spec_from_file_location("safehub_tts_server", Path(__file__).parents[1] / "server.py")
SERVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVER)


class TtsServerTests(unittest.TestCase):
    def client(self, outcome=b"fake-mp3", timeout=12):
        paths, calls = [], []

        class Synthesizer:
            def __init__(self, **kwargs):
                calls.append(kwargs)

            async def save(self, name):
                paths.append(Path(name))
                if outcome == "stall":
                    await asyncio.Future()
                if isinstance(outcome, Exception):
                    raise outcome
                Path(name).write_bytes(outcome)

        client = TestClient(SERVER.create_app(Synthesizer, timeout_seconds=timeout))
        self.addCleanup(client.close)
        return client, paths, calls

    def test_mp3_contract_and_cleanup(self):
        client, paths, calls = self.client()
        response = client.post("/tts", json={"text": "  도움이 필요합니다  "})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, b"fake-mp3")
        self.assertEqual(response.headers["content-type"], "audio/mpeg")
        self.assertEqual(calls, [{"text": "도움이 필요합니다", "voice": "ko-KR-SunHiNeural"}])
        self.assertEqual(len(paths), 1)
        self.assertFalse(paths[0].exists())

    def test_blank_text_does_not_synthesize(self):
        client, paths, calls = self.client()
        self.assertEqual(client.post("/tts", json={"text": "  "}).status_code, 400)
        self.assertEqual((paths, calls), ([], []))

    def test_invalid_request_shapes_do_not_synthesize(self):
        client, paths, calls = self.client()
        for body in [{}, {"text": None}, {"text": []}, {"text": 42}]:
            with self.subTest(body=body):
                self.assertEqual(client.post("/tts", json=body).status_code, 422)
        self.assertEqual((paths, calls), ([], []))

    def test_provider_failure_cleans_file(self):
        client, paths, _ = self.client(RuntimeError("fake provider failure"))
        self.assertEqual(client.post("/tts", json={"text": "안내"}).status_code, 502)
        self.assertEqual(len(paths), 1)
        self.assertFalse(paths[0].exists())

    def test_empty_provider_result_cleans_file(self):
        client, paths, _ = self.client(b"")
        self.assertEqual(client.post("/tts", json={"text": "안내"}).status_code, 502)
        self.assertFalse(paths[0].exists())

    def test_timeout_cancels_synthesis_and_cleans_file(self):
        client, paths, _ = self.client("stall", timeout=.01)
        self.assertEqual(client.post("/tts", json={"text": "안내"}).status_code, 504)
        self.assertFalse(paths[0].exists())

    def test_health_does_not_claim_provider_readiness(self):
        client, paths, calls = self.client()
        data = client.get("/health").json()
        self.assertTrue(data["tts_requires_internet"])
        self.assertFalse(data["stt_supported"])
        self.assertEqual((paths, calls), ([], []))

    def test_old_stt_route_is_not_restored(self):
        client, paths, calls = self.client()
        self.assertEqual(client.post("/stt").status_code, 404)
        self.assertEqual((paths, calls), ([], []))


if __name__ == "__main__":
    unittest.main()
