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

마지막 명령은 서버를 직접 실행할 때 사용하는 예시다.
앱 `TTS_SERVER_URL`은 같은 장치라면 `http://127.0.0.1:8000`으로 설정한다.
설정 화면의 `TTS 서버 주소`에 입력하고 연결 확인 후 저장한다.
Pi5 내부의 주소이므로 Wi-Fi IP가 바뀌어도 같은 값을 사용한다.

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

위 단위 검사는 fake 합성기를 사용한다.

2026-10-27 Pi5에서는 `/opt/safehub-tts/venv`와 `safehub-tts.service`를
설치하고 localhost:8000의 health·실제 합성 응답을 확인했다. 7.2.8에서
외부 합성 요청이 HTTP 403으로 실패하여 edge-tts를 7.3.1로 고정했다.
FastAPI·uvicorn 버전은 유지했다. `safehub-tts.service`는 loopback에만
바인딩하며, ATLAS의 `/opt/safehub-system/boot.sh`에서 시작한다.
부팅 스크립트 원본과 설치 전 앱·프로필은 별도로 백업했다.

앱 1.5.7은 ATLAS의 GStreamer/PulseAudio 경로로 재생한다.
고정 번역 메시지 → 실제 서버 합성 → SafeHub 재생 스트림 생성과,
모의 MQTT 위험 이벤트 → 내장 안내 재생을 확인했다.
이는 실제 카메라·CSI 인식이나 물리 스피커의 음량·가청성 검증과는 다르다.
재부팅 후 자동 시작은 아직 시험하지 않았다.

위험 안내 4종은 앱의 `assets/audio/`에 포함되어 서버·인터넷 없이 재생한다.
일반 수어/문장 합성은 이 서버와 인터넷이 필요하다.
