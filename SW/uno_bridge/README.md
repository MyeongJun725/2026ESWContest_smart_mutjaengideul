# Uno · 수어 단축키 연결 소스

현재 제품은 기존 MQTT 계약으로 팬·커튼·LED·진동 명령을 연결합니다.
UI·Pi5 수어 라우터·Pi4 USB 브리지는 각각 별도 경로이며,
명령 제출·UART echo·실제 움직임 완료를 구별합니다.

| 파일 | 역할 |
|---|---|
| `controller.py` | 명령 검증, 경보 ID/시간 제한, 팬 절대값, 커튼 대기/반전 상태 |
| `bridge.py` | Pi4 MQTT/Arduino USB 연결. 카메라/CSI 포트를 열지 않음 |
| `sign_hub.py` | Pi5의 기존 rpi5_hub 단축키와 절대 명령 상태 동기화 |
| `*.service` | 작성자 배치 경로를 반영한 검토용 설정 |
| `tools/prepare_deployment.py` | 소스·unit 파일 매핑 dry-run 또는 새 외부 폴더 staging |

## 제품 계약

- 팬은 기존 `safehub/control/livingroom/aircon/command`의 절대 `set_power`/bool 값입니다.
  `aircon` ID와 에어컨 수어 라벨은 호환성을 위해 남겼고 UI는 팬으로 표시합니다.
- 커튼은 기존 topic template의 `curtain`을 사용합니다. `set_power`와 `stop`을 받습니다.
  수신 후 2초 만료/반전 정지·대기는 브리지 코드의 제한이며 발행 시각 검증이나 실제 위치 피드백이 아닙니다.
- LED·진동은 `safehub/actuator/{device}/command`를 사용합니다. ID·timestamp·action과 진동 duration을 검사합니다.
  브리지 실행 중 최대 10초 제한과 펌웨어 watchdog은 다릅니다.
- 수어 DUP 캐시는 clean MQTT session마다 초기화하고 같은 세션의 재전송은 억제합니다.
  실제 사고 message_id 중복 방지는 별도입니다. 전원/세션/프로세스를 넘는 exactly-once 보장은 없습니다.
- Pi4 브리지는 `MQTT_BROKER`/`MQTT_PORT`, Pi5 hub는 `MQTT_BROKER_HOST`/`MQTT_BROKER_PORT`를 사용합니다.

[토픽·payload 원문](../../config/topics.json)은 유지했습니다. 실제 환경의 주소·단축키·배치 설정은 Git에 넣지 않습니다.

## 비장비 검사와 staging

paho-mqtt 2.1.0, pyserial 3.5가 설치된 Python 3.12 환경에서 저장소 루트 기준:

```sh
python3 -m unittest discover -s SW/uno_bridge/tests -p 'test_*.py' -v
python3 tools/run_hub_checks.py
python3 SW/uno_bridge/tools/prepare_deployment.py
```

Uno 검사 15개와 별도의 허브 14개 assertion 스크립트는 fake client/시계/쓰기 함수를 씁니다.
허브 runner는 Python socket 연결을 차단합니다. 마지막 명령은 파일 매핑만 출력합니다.
`--output <새 외부 경로>`는 소스/unit 사본과 SHA256을 만들며 의존성 설치·모델·개인 설정 복사는 하지 않습니다.

서비스 entrypoint를 직접 실행하는 것은 dry-run이 아닙니다. `bridge.py`는 시작 시 Uno USB를 열고
F/V/L/s probe를 쓰며, `sign_hub.py`에는 help-only CLI가 없습니다. 소스 검사는 위 명령으로 수행합니다.
이번 작업에서는 실제 보드/브로커/서비스를 실행하거나 명령을 발행하지 않았습니다.

## 실제 장치 확인이 남은 것

Uno .ino·보드/핀·펌웨어 버전·1.5초 정지·watchdog, 모터/LED/진동 동작,
실제 마이크·수어부터 장치까지의 흐름과 재부팅은 미확인입니다.
[PR #10 작성자 보고](../../docs/UNO_INTEGRATION.md)는 이번 직접 장치 확인 결과와 구별합니다.
[최신 제출 점검](../../docs/integration/submission-audit-20261027.md)을 기준으로 검토하세요.
