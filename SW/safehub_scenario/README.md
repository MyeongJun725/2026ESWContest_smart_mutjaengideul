# SafeHub 현재 UI

이 폴더가 PR #11 통합 후보의 UI·빌드 진입점입니다. #10의 새 UI·장치 제어와
#6 안정화, #9 수어 후보 소스를 함께 검토합니다. #10에 #8/#7이 포함돼 있습니다.
옛 `SW/safehub_app`을 복사하거나 함께 실행할 필요는 없습니다.
필수 runner·manifest·record_atlas·이미지·폰트는 이 폴더에 있습니다.

## 준비와 실행 경로

저장소 루트에서:

```sh
# 호스트 패키징 검사 (Flutter/장치 불필요)
python3 -m unittest discover -s SW/safehub_scenario/tool -p 'test_*.py' -v

# 브라우저 화면 시연; --check-only는 준비 검사만 수행
python3 SW/safehub_scenario/tool/run_ui_preview.py --check-only
python3 SW/safehub_scenario/tool/run_ui_preview.py

# 실제 현재 소스·테스트·자산을 새 외부 폴더로 복사
python3 SW/safehub_scenario/tool/prepare_host_tests.py /tmp/safehub-scenario-host
```

생성한 호스트에서 `flutter pub get`, `flutter test`를 실행합니다.
검증에 사용한 호스트 SDK는 Flutter 3.35.7 / Dart 3.9.2입니다.
[Windows 준비](../windows_preview/README.md)도 이 폴더를 원본으로 사용합니다.
호스트 준비 도구는 CSI 서비스나 옛 UI 도우미를 import하지 않습니다.

ATLAS 빌드는 이 폴더에서 팀의 ATLAS SDK와
`/opt/flutter-atlas-plugins/packages/flutter-plugin-atlas-audioplayers`를 사용합니다.
`atlas/`의 [출처와 한계](atlas/PROVENANCE.md), [권한 안내](atlas/README.md)를 확인하세요.
표준 호스트에서 제외한 ATLAS 플러그인의 ABI·권한·실제 장비 동작은 호스트 검사로 입증되지 않습니다.

## 기능과 시연

현재 소스에는 방송 자막·재난 안내·수어/터치 도움 흐름, 카메라, 가전/단축키,
CSI 상태/수집 화면, 문맥 설명과 시나리오·장치 테스트가 있습니다.
CSI 화면 범위, 테스트 UI 노출, 설명 엔진과 제품 가전 범위는
[사용자 결정 목록](../../docs/integration/ui-consolidation-20261027.md)에 남겼습니다.
이번 정리는 제품 기능이나 기존 사용자 설정을 조용히 제거/변경하지 않습니다.

[시나리오 및 장치 테스트](docs/scenario-event-overlays.md)는 화면 전용과 장치 연동을 구별합니다.
**#10의 장치 테스트는 실제 MQTT 명령을 발행할 수 있습니다.**
연동 모드 선택만으로 전송이 보장되지는 않으며 preview/활성화/LED action/MQTT 조건의
영향을 받습니다. 명령 제출·UART 응답과 물리 동작 완료는 서로 다릅니다.
실제 신고·보호자 메시지 전송·의식불명 확정 기능은 구현하지 않았습니다.
경보와 도움 화면은 설명 서버의 응답을 기다리지 않습니다.

## 앱 식별과 설정

- 설치 앱 ID: `com.atlas.app.safehub_scenario_pr7`
- Dart package / 실행 파일: `safehub_app` — 옛 UI 폴더를 참조한다는 뜻이 아닙니다.
- 소스 후보: pubspec 1.4.0+1 / manifest 1.4.0
- 기본 설정 경로: 앱 계정의 `SafeHubScenarioData`; `SAFEHUB_SCENARIO_CONFIG_FILE` 등 명시적 override가 우선합니다.

1.2.0은 과거 사용자 확인, 1.4.0 설치는 #10 작성자 보고입니다.
현재 장치 버전·배치·IPK·ELF·보관본은 **미확인/미확보**이며 없다고 단정하지 않습니다.
runner의 버전 번호를 맞춘 것만으로 설치본 재현을 선언하지 않습니다.

## 검증

[현재 검토·수치·장치 확인 목록](../../docs/integration/pr10-addendum-review.md)을 기준으로 합니다.
전체 Flutter 265 pass / 0 fail / 1 opt-in live LLM skip; 이후 경고 수정의 영향 경로 13개도 통과했습니다.
정적 분석은 error 0 / warning 11 / info 100, exit 1입니다.
Preview web release 빌드는 통과했으나 ATLAS 패키지 빌드·재부팅·실제 모델·마이크부터
물리 장치까지의 동작은 미검증입니다. 모델·비공개 SDK·인증정보·개인 설정은 포함하지 않습니다.
