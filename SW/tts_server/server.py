"""Current /tts contract, adapted from voice-server-port at 25be72e.

No Whisper/STT/model download path. Network synthesis occurs only on /tts requests.
Tests inject a synthesizer and make no external requests.
"""
import asyncio
from pathlib import Path
import tempfile

from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel


class TtsRequest(BaseModel):
    text: str


def edge_communicate(**kwargs):
    import edge_tts
    return edge_tts.Communicate(**kwargs)


def create_app(communicate_factory=None, *, timeout_seconds=12):
    app = FastAPI(title="SafeHub TTS Server")
    factory = communicate_factory or edge_communicate

    @app.get("/health")
    async def health():
        return {"status": "ok", "tts_requires_internet": True,
                "voice": "ko-KR-SunHiNeural", "stt_supported": False}

    @app.post("/tts")
    async def tts(request: TtsRequest):
        text = request.text.strip()
        if not text:
            raise HTTPException(status_code=400, detail="TTS 문장이 비어 있습니다.")
        temporary_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as output:
                temporary_path = output.name
            try:
                communicate = factory(text=text, voice="ko-KR-SunHiNeural")
                await asyncio.wait_for(communicate.save(temporary_path), timeout_seconds)
            except asyncio.TimeoutError as exc:
                raise HTTPException(status_code=504, detail="TTS 음성 생성 시간이 초과되었습니다.") from exc
            except Exception as exc:
                raise HTTPException(status_code=502, detail="TTS 음성을 생성하지 못했습니다.") from exc
            audio = Path(temporary_path).read_bytes()
            if not audio:
                raise HTTPException(status_code=502, detail="TTS 음성을 생성하지 못했습니다.")
            return Response(content=audio, media_type="audio/mpeg")
        finally:
            if temporary_path:
                Path(temporary_path).unlink(missing_ok=True)

    return app


app = create_app()
