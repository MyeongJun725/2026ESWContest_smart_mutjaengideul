# 현재 앱용 TTS API

수어를 음성으로 전달하는 현재 `TtsService`의 `POST /tts` 서버 소스다.
`feature/voice-server-port`의 `SW/voice_server/server.py`, 커밋
[`25be72eaa6d04ff3a9d4853b62c6912e48530034`](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/commit/25be72eaa6d04ff3a9d4853b62c6912e48530034)의
TTS 경로를 분리·정리했다. 현재 로컬 STT와 중복되는 Whisper/모델 다운로드/파일 STT는 복구하지 않았다.

Python 3.12 환경에서 이 폴더를 작업 디렉터리로 사용한다. 가상환경은 저장소 밖에 준비한다.

```sh
python3 -m venv /tmp/safehub-tts
/tmp/safehub-tts/bin/python -m pip install -r requirements.txt
/tmp/safehub-tts/bin/python -m uvicorn server:app --host 127.0.0.1 --port 8000 --workers 1
```

마지막 명령은 서버를 실제로 실행하는 명령이다. 이번 클라우드에서는 실행하지 않았다.
앱 `TTS_SERVER_URL`은 같은 장치라면 `http://127.0.0.1:8000`으로 설정한다.
다른 서버를 사용하던 개인 설정을 자동 변경하지 않으며 부팅 unit도 추가하지 않았다.

- `POST /tts`, JSON `{"text":"도움이 필요합니다"}` → `audio/mpeg`.
- 빈 문자열 400, 잘못된 형식 422, 외부 합성 실패/빈 결과 502, 시간 초과 504.
- 앱의 기존 15초 제한 안에 오류 응답을 보낼 수 있도록 합성 제한은 12초다.
  네트워크·스케줄링 지연까지 15초 이내임을 보장하는 값은 아니다.
- edge-tts의 `ko-KR-SunHiNeural`을 사용하며 **실제 합성에는 인터넷이 필요**하다.
  `/health`는 외부 연결·스피커·실제 합성 성공을 검사하지 않는다.
- 임시 MP3는 응답/실패/시간 초과 시 삭제하며 텍스트와 음성을 별도로 저장하거나 출력하지 않는다.

실제 합성 없이 ASGI HTTP 계약·오류·시간 초과·임시 파일 정리를 검사한다:

```sh
/tmp/safehub-tts/bin/python -m pip install -r requirements-test.txt
/tmp/safehub-tts/bin/python -m unittest discover -s tests -p 'test_*.py' -v
```

검사는 fake 합성기다. 실제 인터넷 합성·음질·ARM64 설치·ATLAS 스피커는 미검증이다.
FastAPI/uvicorn/edge-tts 고정 버전은 팀의 원래 voice-server-port 기록을 유지했다.
