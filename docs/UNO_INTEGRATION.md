# Uno 장치 연동

2026-10-26. UI 기준은 PR #8의 `9037ac9`이며 원래 SafeHub와 수어 모델을 교체하지 않는다.

## 역할과 연결

| 장치 | 역할 | 연결 |
|---|---|---|
| Pi4 | 기존 카메라·수어 인식, 별도 Uno USB 어댑터 | Uno를 데이터 USB로 연결 |
| Pi5 | UI, 기존 MQTT·CSI·STT, fastText 문맥 요약, 수어 제어 라우터 | ESP32 수신기는 기존 USB 유지 |
| Uno | 제공된 스케치 그대로 LED·진동·팬 실행 | 9600 baud, Arduino USB by-id 경로 |

Pi4 `safehub-uno.service`는 카메라를 열지 않는다. `run_camera.sh`의 기존 `MQTT_BROKER` 값을 읽고 주소가 바뀌면 재접속한다. Pi5의 `safehub-sign-control.service`는 기존 `rpi5_hub` 코드를 사용한다. 첫 실행에만 에어컨 단축키를 등록하고 이후 사용자 설정을 보존한다.

| Uno 핀 | 기능 | 사용 명령 |
|---|---|---|
| D5 | 팬 | `f` ON / `F` OFF |
| D6 | 베드셰이커 | `v` ON / `V` OFF |
| D9 | LED | `l` ON / `L` OFF, Pi4에서 250ms 간격 점멸 |
| D2 / D3 | 초인종 / 부저 | 기존 스케치 유지. 이번 변경에 초인종 이벤트의 UI 전달은 포함하지 않음 |
| D7 / D8 | 커튼 드라이버 | `u` 올림 / `j` 내림 / `s` 정지. 기존 펌웨어 이동 제한은 1500ms |

모터는 기존 드라이버와 전원 회로를 사용한다. 이 변경은 배선이나 Uno 펌웨어를 다시 설치하지 않는다.

## 사용자 조작

- 상단 **장치 테스트**: 문장 입력 판별, 화재·재난·낙상 의심 모의 입력, 팬 ON/OFF, 경보 끄기.
- 이 창의 모의 입력은 **실제 LED·진동·팬**을 작동시킨다. 실제 재난 접수나 CSI 검출 시험이 아니다. 커튼 올림·내림·정지 버튼도 제공한다.
- **시나리오 테스트**의 기본값은 실제 LED·진동 연동이다. **화면·장치 함께 실행**을 누르면 선택한 상황의 화면과 장치 명령이 함께 시작된다. 스위치를 끄면 화면만 시험한다. 시연 종료와 경보 확인 시 LED·진동을 끈다.
- LED·진동은 어댑터가 실행 중이면 최대 10초 후 종료한다. 팬은 유지되며 별도로 끈다. 경보만 끄면 팬 상태는 바뀌지 않는다.
- 창 닫기는 팬 OFF 명령이 아니다. 모두 끄려면 **팬·LED·진동 모두 끄기**를 누른다.
- 실제 방송·재난·낙상 의심 이벤트는 기존 화면 경보와 연결한다. 지역 재난 자동 작동에는 집 지역 설정이 필요하다. 전국 알림은 예외다.
- 에어컨 수어는 기존 단축키에서 ON/OFF를 전환한다. 수동 팬 시험도 같은 논리 상태에 반영한다.
- **가전 → 수어 단축키**에서 기기와 동작을 선택할 수 있다. 커튼에 현재 인식 가능한 수어를 연결한다. 예를 들어 점등→커튼 올림, 소등→커튼 내림으로 직접 등록할 수 있다. 인식 모델에 새로운 커튼 수어가 추가된 것은 아니다. 기존 단축키는 임의로 재배정하지 않는다.
- 커튼 역방향 전환은 먼저 정지하고 250ms 기다린다. 펌웨어의 자동 정지 후에도 같은 대기 시간을 둔다. 이동 명령은 2초 후 폐기하고 USB 재접속 후 재생하지 않는다.

## MQTT 계약

기존 토픽 이름과 JSON key는 변경하지 않았다. 커튼은 기존 `safehub/control/{room}/{device}/command` 생성 규칙에 맞춰 `device=curtain` 경로를 활성화했다. 새 JSON key는 없다. 아래 커튼 경로와 stop 값이 이번 기능 확장 범위다.

| 기존 토픽 | 기존 내용 |
|---|---|
| `safehub/actuator/led/command` | `message_id`, `device:rpi5_hub`, `event:led_command`, `action:on/off/blink`, `timestamp` |
| `safehub/actuator/bedshaker/command` | `message_id`, `device:rpi5_hub`, `event:bedshaker_command`, `action:on/off`, `timestamp`, `duration_sec` |
| `safehub/control/livingroom/aircon/command` | `source`, `action:set_power`, `power_on:boolean` |
| `safehub/control/livingroom/curtain/command` | 같은 `source`, `action:set_power/stop`, `power_on:boolean`. true=올림, false=내림, stop에서는 전원값 무시 |

수어의 `source`는 기존 `sign_shortcut`, 수동 시험은 같은 문자열 필드의 `manual_test` 값이다. 명령은 retain 없이 전송한다. 경보는 message_id 중복, 오래된 timestamp, 잘못된 duration을 거절한다. 팬은 절대 전원값이므로 재전송을 토글로 해석하지 않는다. 라우터는 5초마다 현재 절대 전원값을 다시 보낸다. 라우터 재시작 시 팬의 기본값은 OFF다.

USB를 열면 Uno가 리셋될 수 있다. 어댑터는 2.5초 기다리고 `F/V/L` 응답을 모두 확인한 후 명령을 전달한다. ESP32 포트를 추측해서 열지 않는다. 이 스케치 자체에는 통신 단절 watchdog이 없으므로, 어댑터가 중단된 모든 경우에 10초 정지를 보장하는 펌웨어는 아니다.

## fastText와 경보 판정

사용자가 설치한 `fire_screen_model.bin`을 사용한다. 모델은 `FIRE/NOTICE/DRILL` 분류기이며 생성형 LLM이나 음향 모델이 아니다. 실제 모델에서 부정문도 FIRE 점수가 높게 나온 것을 확인했으므로 점수를 위험 확률로 표시하거나 단독 작동 근거로 사용하지 않는다.

`/classify`는 명시적 위험 표현·부정·훈련 문맥을 함께 검사한다. `/v1/chat/completions`는 기존 UI가 읽는 짧은 문맥 요약 형식만 호환한다. 생성형 대화나 카메라 분석은 하지 않는다. 확정적 방송 경보는 음향 교차검증을 기다리지 않는다. 새로운 부정문으로 이미 발생한 경보를 자동 해제하지 않는다.

서버는 Pi5의 `127.0.0.1:9380`에만 바인딩한다. Gemma는 복구하지 않았다. fastText venv의 Python은 남아 있는 `/opt/safehub-csi/python/bin/python3.12`를 사용한다.

## 설치 구조와 복구

- Pi4: `/data/safehub-uno/{python,packages,app}`, `safehub-uno.service`.
- Pi5: `/data/safehub-sign-control/{packages,app/hub,state}`, `safehub-sign-control.service`.
- Pi5 fastText: `/data/safehub/fasttext/{venv,app,fire_screen_model.bin}`, `safehub-fasttext.service`.
- Python 의존성: `paho-mqtt==2.1.0`, `pyserial==3.5`. 학습 패키지는 추가하지 않는다.
- ATLAS의 `/etc`가 읽기 전용이므로 `/data/share/usr/lib/systemd/system/multi-user.target.wants/`에 서비스 링크를 만들었다. 전원 복구 뒤 Pi5 fastText가 시작되지 않은 것을 확인해 기존 `/opt/safehub-system/boot.sh`에 STT·fastText·수어 제어 라우터의 선택적 시작을 추가했다. 이 스크립트는 `/data` mount 뒤 daemon-reload를 수행한다. 변경 뒤 실제 재부팅 시험은 하지 않았다. `is-enabled`만으로 이 구성을 판단하지 않는다. Pi4의 기존 비전 부팅 경로는 변경하지 않았다.

Pi5 새 UI 앱 ID는 `com.atlas.app.safehub_scenario_pr7`, 패키지 버전은 **1.4.0**이다. ID의 pr7은 호환성 때문에 유지한다. PackageManager 갱신으로 배치·주소·연결 설정을 보존했다. 설치 후 배치 파일 SHA256이 설치 전과 같았다. 기존 앱 제거 또는 ClearAppData를 실행하지 않는다.

백업: `/data/safehub-pr7/releases/uno-orchestration-20261026/before-ui-and-settings.tar.gz`.
새 패키지: 같은 폴더의 `com.atlas.app.safehub_scenario_pr7_1.4.0_all.ipk`.
직전 복구 패키지: `/data/safehub-pr7/releases/uno-ui-20261026/com.atlas.app.safehub_scenario_pr7_1.3.0_all.ipk`.
Pi4 어댑터 코드 백업: `/data/safehub-uno/backups/before-curtain-20261026.tar.gz`.
백업에는 연결 정보가 포함되므로 Git에 올리지 않는다.

앱 갱신 명령은 다음 순서다. 먼저 사용자의 배치를 저장한다.

```sh
busctl --system call com.atlas.AppManager1 /com/atlas/AppManager1 com.atlas.AppManager1 Stop s com.atlas.app.safehub_scenario_pr7
busctl --system call com.atlas.PackageManager1 /com/atlas/PackageManager1 com.atlas.PackageManager1 Install ss com.atlas.app.safehub_scenario_pr7 /absolute/path/to/package.ipk
busctl --system call com.atlas.AppManager1 /com/atlas/AppManager1 com.atlas.AppManager1 Start s com.atlas.app.safehub_scenario_pr7
```

이 OS에서 이전 버전 패키지 설치가 거절되면 패키지를 제거하지 말고, 백업의 앱 폴더와 필요한 설정만 복구한다. 사용자 배치가 이후 변경됐다면 최신 배치를 별도로 보존한다. UID/GID와 접근권한도 함께 보존한다. 서비스 롤백은 새 서비스만 중지하고 위 Wants 링크를 해제한다. 기존 카메라·CSI 서비스를 재설치하거나 비전 바이너리를 덮어쓰지 않는다.

## 검증 결과

| 범위 | 결과 |
|---|---|
| Flutter 1.4 연동 검사 | 23개 통과: 시나리오→장치 콜백, 실제 확정 자막→위험 알림, 중복·부정문, 커튼 버튼, 기존 가전·MQTT·화면 테스트. 1.3 단계의 관련 검사 24개도 별도 통과 |
| Uno·단축키 합성 단위 검사 | 14개 통과: 타이머, 중복, 재접속, 팬 보존, 커튼 역방향·재시작 대기·만료·정지, 단축키 메시지 |
| fastText 문맥 규칙 합성 검사 | 6개 통과. 실제 학습 모델 정확도 검사가 아님 |
| 기존 허브 검사 | 외부 브로커 연결 전용 스크립트를 제외한 14개 스크립트 통과. 수동 전원 동기화 회귀도 추가 확인 |
| 부팅 스크립트 | 실제 Pi5에서 systemctl을 임시 stub으로 바꾼 4개 검사 통과. Windows는 sh 부재로 실행 불가 |
| 실제 명령 전달 | 21:23 KST MQTT → Pi4 → Uno UART의 f/v/l/L/V/F 응답 확인. 경보 OFF 후 팬 유지, 마지막 팬 OFF 확인 |
| 실제 커튼 명령 | 22:01 KST UP→STOP→DOWN→STOP UART 응답 확인. 각 이동 약 355ms 후 정지. 실물 움직임의 육안 확인은 별도 |
| UI | Pi5 1.4.0 Running·window active, 배치 SHA 보존. Windows 실행본도 다시 빌드 |

위 실제 명령 시험은 수어 또는 CSI로 위험을 실제 검출한 시험이 아니다. 모터 회전·진동·LED 배선의 현장 육안 확인, 실제 마이크 발화부터 장치까지의 지연·오탐, 에어컨 수어부터 팬까지의 실제 동작 시연, 재부팅 복귀, 낙상 정확도는 별도 확인이 필요하다. YAMNet·화재 경보음 학습·119 실제 신고는 구현했다고 표시하지 않는다.

기존 `scenario_event_overlay_test.dart` 10개 중 8개는 삭제된 119 모달·옛 문구를 기대해 실패한다. 수정 전 PR8 `9037ac9`의 UI·서비스·흐름 소스로 다시 실행해도 같은 8개가 실패했다. 이 결과를 통과로 바꾸거나 새 연동 검사와 합산하지 않는다. 최신 UI의 시나리오 선택·장치 콜백은 별도 `orchestration_ui_test.dart`와 `scenario_actuation_test.dart`로 검증했다.

PR #6의 MQTT 수신 순서·중복 방지·QoS1·오디오 시간 제한·STT 시작 보완을 이식했다. PR #6 전체 기능의 대체 여부는 확인하지 않았으므로 닫거나 삭제하지 않는다.
