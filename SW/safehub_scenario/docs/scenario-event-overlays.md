# 현재 UI의 시나리오·장치 테스트

기본 제품 화면에는 이 테스트 UI가 없습니다. 브라우저는 `--developer-tools`,
실제 연결용 개발 빌드는 `SAFEHUB_DEVELOPER_TOOLS=true`를 명시해야 표시됩니다.
[승인된 제품 구성](../../../docs/integration/product-scope-20261027.md)을 기준으로 합니다.

현재 소스는 `SW/safehub_scenario`입니다. 아래는 PR #10과 안정화 보완을 반영한
검토 후보의 설명입니다. [이전 화면·배포 기록](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/blob/654e2f3cb09a1778d65ba6554bc35b94e1679e6e/SW/safehub_scenario/docs/scenario-event-overlays.md)은
과거 기록이며 현재 장치 상태를 증명하지 않습니다.

## 화면만 확인하기

저장소 루트에서 Python 3와 Flutter SDK를 사용합니다.

```sh
python3 SW/safehub_scenario/tool/run_ui_preview.py --check-only
python3 SW/safehub_scenario/tool/run_ui_preview.py
```

Flutter가 PATH에 없으면 `--flutter-path <Flutter 실행 파일>`을 지정합니다.
`--no-browser`는 브라우저 자동 열기를 생략하고, `--port`는 개발 서버 포트를 바꿉니다.
종료는 Ctrl+C입니다. 도우미는 현재 폴더의 lib·assets를 임시 호스트에 복사해
`APP_LOCAL_PREVIEW=true`로 웹 빌드하며, 원본·장치·개인 설정을 바꾸지 않습니다.
브라우저 복사본에서만 파일 설정 접근과 ATLAS 전용 플러그인을 조정합니다.
이는 실제 카메라 인식·음성 입력·물리 장치 시험이 아닙니다.

## 화면 전용과 장치 연동

시나리오 선택 창의 **장치 연동**을 끄면 **화면만 실행**으로 확인할 수 있습니다.
PR #10에는 장치 연동 선택과 별도의 **실제 장치 테스트** 창이 들어 있습니다.
따라서 모든 테스트가 실제 명령을 보내지 않는다고 설명하면 안 됩니다.

- preview 빌드 여부, `SituationSettings.actuatorsEnabled`(기본 false), MQTT 연결,
  LED ON/OFF action(기본 빈 값), 지역 재난의 homeRegion 설정을 확인해야 합니다.
- 화면 전용 시나리오는 실제 장치 명령을 보내지 않습니다. 실제 연동 시나리오는
  조건을 만족해야 전달되며 실패/미설정 상태와 명령 제출 상태를 표시합니다.
- 장치 테스트 창은 팬·LED·진동·커튼 명령을 발행할 수 있습니다.
  **팬·LED·진동 끄고 커튼 정지**는 각 제출 결과를 합쳐 표시합니다.
  창을 닫는 것만으로 팬이 꺼지지는 않습니다.
- LED·진동 최대 10초는 브리지 프로세스가 실행 중인 경우의 제한입니다.
  펌웨어 watchdog이나 실제 모터 정지는 현재 클라우드에서 확인하지 못했습니다.

이번 작업은 실제 장치 명령을 보내거나 이 창을 장비에 연결해 시험하지 않았습니다.
테스트 UI는 사용자 승인대로 개발·시연 모드에만 노출합니다.

## 사건·도움·카메라 동작

방송·재난 화면은 원문과 확인·도움 선택을 제공합니다. 도움 화면은 본인/다른 사람과
반응 여부를 구분하고 가족 전달문·119 신고문을 준비합니다. 실제 연락/신고 전송은 없습니다.
도움 취소나 새 부정문이 진행 중인 실제 화재·재난 경보를 자동 해제하지 않습니다.

시나리오는 별도 상태를 쓰며 실제 사건을 우선합니다. 이미 선점된 시연의 늦은 종료가
실제 사건의 장치 경보를 끄지 않도록 보호합니다. 카메라는 원래 비율(contain)을 유지하며
연결 해제·재연결·dispose 이후 늦은 프레임 콜백을 폐기합니다.
화면 배치는 앱 계정의 `SafeHubScenarioData/ui-layout.json`에 저장하며 `.previous`를 보존합니다.

## 검사

현재 소스·테스트를 `tool/prepare_host_tests.py`로 준비한 호스트에서:

```sh
flutter test test/scenario_event_overlay_test.dart test/scenario_actuation_test.dart test/hardware_test_dialog_test.dart
```

최종 전체 Flutter 271 pass/실제 fastText 1 skip과 개발 모드 6 pass, 정적 분석의 남은 경고 및
실기 미검증 범위는 [현재 검토 기록](../../../docs/integration/pr10-addendum-review.md)에 있습니다.
명령 제출·UART 응답·실제 물리 동작 완료를 구분하며, 호스트 통과로 장치 배포 완료를 표시하지 않습니다.
