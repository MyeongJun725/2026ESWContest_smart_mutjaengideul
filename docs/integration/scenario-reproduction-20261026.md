> 이전 PR #8 중심 검토의 역사 기록입니다. 현재 판단·범위·검증은 [PR #10 추가 통합 기록](pr10-addendum-review.md)이 우선합니다.

# Scenario 후보 재현 및 적용·복원 준비

모든 아래 호스트 검사는 **Debian 클라우드/별도 worktree** 기준이다.
장치 적용은 사용자의 후속 지시 전에는 실행하지 않는다.

## Flutter 도구 확보와 고정

기존 `/workspace/.cloud-setup/flutter-sdk`가 있으면 먼저 버전을 확인하고 재사용한다.
없을 때 공식 저장소의 3.35.7 태그를 새 SDK 캐시 폴더로 clone한다.
이번에 확인한 framework SHA는 `adc901062556672b4138e18a4dc62a4be8f4b3c2`,
engine revision은 `035316565ad77281a75305515e4682e6c4c6f7ca`, Dart는 3.9.2다.
공식 tar/목록 경로가 404여서 SDK 자체 bootstrap으로 준비했으며 검증을 끄지 않았다.

```sh
git clone --depth 1 --branch 3.35.7 https://github.com/flutter/flutter.git /workspace/.cloud-setup/flutter-sdk
export PATH=/workspace/.cloud-setup/flutter-sdk/bin:$PATH
export XDG_CONFIG_HOME=/workspace/.cloud-setup/flutter-config
export XDG_CACHE_HOME=/workspace/.cloud-setup/flutter-cache
export PUB_CACHE=/workspace/.cloud-setup/pub-cache
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter --version
```

SDK 명령은 readonly home 대신 위 설정·패키지 캐시를 사용한다. standalone Dart
formatter가 home에 analytics 파일을 만들려 하면 값 변경 없이 그 자식 프로세스에만
`env -u HOME`을 적용할 수 있다. SDK를 설치했다고 ATLAS plugin/sysroot가 생기는 것은 아니다.

## UI 호스트 검사

```sh
cd /workspace/safehub-integration
python3 SW/atlas_boot/test_boot.py
python3 SW/safehub_scenario/tool/test_reproduction.py
python3 -m unittest discover -s SW/windows_preview -p 'test_*.py' -v
python3 SW/safehub_scenario/tool/run_ui_preview.py --check-only
python3 SW/safehub_scenario/tool/prepare_host_tests.py /tmp/safehub-scenario-host-new
cp docs/integration/scenario-host-pubspec.lock /tmp/safehub-scenario-host-new/pubspec.lock
cd /tmp/safehub-scenario-host-new
flutter --version
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
```

출력 폴더는 새 폴더여야 한다. helper는 새 앱의 lib/test/assets를 그대로 복사하고
**사본의** `audioplayers_atlas`, `record_atlas` path 의존성만 제외한다.
ATLAS 원본 pubspec, lock, plugin 및 소스를 덮어쓰지 않는다. SDK 버전과 host에서
해결한 lock을 검증 기록에 보존한다. host plugin 제외 검사와 실제 ATLAS 빌드를 구분한다.
이번에는 위 흐름의 의존성 해결과 Flutter 검사를 직접 실행했다.
전체 테스트는 243 pass / 1 opt-in live LLM skip / 0 fail이다. analyzer는
0 error / 11 warning / 93 info로 exit 1이며, 같은 SDK/lock의 PR #8 원본과 동일하고
새 warning/error signature는 0개다. 경고를 없애려고 legacy helper를 삭제하지 않았다.

전체 Flutter suite에서 카메라 decode 지연/재연결/dispose, MQTT transport/lifecycle,
중복 사건·수어 반복, audio timeout/dispose, 레이아웃 저장/재생성, 800×480 화면과
글자 배율, 도움 즉시 표시·위험 취소/우선순위, 자막·가전·CSI를 확인한다.
`scenario_event_overlay_test.dart`는 옛 119 모달 대신 현재 도움 화면을 검사한다.
UI 요구에 맞춘 변경이며 안전 검사를 삭제하거나 skip으로 숨기지 않았다.
opt-in live LLM 검사 skip과 일반 회귀 실패는 별도로 기록한다.

실제 UI 후보 소스는 `SW/safehub_scenario`, package/executable은 `safehub_app`,
앱 ID는 `com.atlas.app.safehub_scenario_pr7`, manifest는 `atlas/meta/appinfo.json`이다.
ATLAS ARM64 패키징에는 해당 장치와 맞는 Flutter-ATLAS SDK, sysroot, plugin 경로가
추가로 필요하다. runner의 [출처와 한계](../../SW/safehub_scenario/atlas/PROVENANCE.md)를
먼저 확인한다. 이를 확보하지 않고 배포용 IPK가 빌드됐다고 기록하지 않는다.

## 검토용 웹 빌드와 화면

아래는 preview adapter를 쓰는 **격리 사본** 빌드이며 ATLAS 패키징이 아니다.
이번 호스트에서 release 빌드 exit 0을 확인했다.

```sh
cd /workspace/safehub-integration
python3 - <<'WEBHOST'
from pathlib import Path
import sys
sys.path.insert(0, 'SW/safehub_scenario/tool')
from run_ui_preview import prepare_host
prepare_host(Path('/tmp/safehub-scenario-web-new'))
WEBHOST
cp docs/integration/scenario-host-pubspec.lock /tmp/safehub-scenario-web-new/pubspec.lock
cd /tmp/safehub-scenario-web-new
flutter pub get --enforce-lockfile
flutter build web --release --dart-define=APP_LOCAL_PREVIEW=true --no-web-resources-cdn
```

이번 산출물은 `/workspace/.cloud-setup/scenario-web-host/build/web`에 있다.
검토용 widget 캡처는 [후보 홈](scenario-host-captures/demo-home.png),
[미전송 도움 문안](scenario-host-captures/scenario-response.png)이다. 장치 화면·실제 카메라나
승인된 장치 배치를 확보한 사진이 아니다. 캡처에는 호스트 UTC 시계와 debug 표시가 있다.
`SCENARIO_SCREENSHOTS=<출력폴더>`로 Flutter 테스트의 캡처를 다시 생성할 수 있다.

## PR별 호스트 재현

별도 PR #9 checkout `ae887ac277bb0e3fc95ad4dc766f678b29bb9876`에서:

```sh
export PATH=/workspace/.cloud-setup/safehub-venv/bin:$PATH
cmake -S tools/sign_regressions -B /workspace/.cloud-setup/pr9-sign-build -DCMAKE_BUILD_TYPE=Release
cmake --build /workspace/.cloud-setup/pr9-sign-build --parallel 3
ctest --test-dir /workspace/.cloud-setup/pr9-sign-build --output-on-failure
python3 -m unittest discover -s SW/rpi4_vision_atlas/tests -p test_sign_capture_diagnostics.py -v
```

현재 호스트 결과는 19 C++ / 3 Python 통과다. ARM64 재현에는 #9의
`docs/sign/word1229-portable-build.md`에 지정한 **수집 사본과 고정 도구/헤더**를
먼저 확보하고 모든 해시를 확인한다. x86 라이브러리로 대신하지 않는다.
`verify_candidate_abi.py`의 성공도 실제 카메라/모델 실행 성공으로 확대하지 않는다.

별도 PR #10 checkout `da7248fac4c00f92f7a9a4fa265c733c9e73f765`에서:

```sh
python3 -m unittest discover -s SW/uno_bridge/tests -p 'test_*.py' -v
python3 -m unittest discover -s SW/fasttext_context/tests -p 'test_*.py' -v
```

합성 controller/shortcut 14개와 context 규칙 6개 통과다. `.ino`가 없어 Uno 보드
컴파일은 미실행이며 serial 포트나 실제 MQTT 액추에이터 토픽에 접속하지 않는다.

## 실제 1.2.0 대응 자료 확보 — 읽기 전용 RPi5 shell

사용자가 장치 자료 조회를 지시할 때 아래 내용을 확인한다. **이 작업에서는 실행하지 않았다.**

```sh
app_id=com.atlas.app.safehub_scenario_pr7
busctl --system call com.atlas.AppManager1 /com/atlas/AppManager1 com.atlas.AppManager1 GetInfo s "$app_id"
busctl --system call com.atlas.AppManager1 /com/atlas/AppManager1 com.atlas.AppManager1 GetStatus s "$app_id"
systemctl show safehub-ui.service -p FragmentPath -p DropInPaths -p ExecStart -p User
systemctl show safehub-stt.service -p LoadState -p FragmentPath -p DropInPaths
```

GetInfo의 실제 앱 계정을 확인하고 `getent passwd <앱계정>`에서 home을 조회한다.
root/HOME을 가정하지 않는다. 그 계정의 `SafeHubScenarioData/ui-layout.json`과
`.previous`, 앱 데이터 경로와 소유권을 **비공개 보관본**에 포함한다.
커밋할 배치는 `status/camera/captions/notices/help/csi`의 유한한 x/y/w/h 값만
선별한다. 연결 주소·토큰·개인 설정 전체를 Git에 넣지 않는다.

설치 package manifest/runner, 실제 build source commit + staged/unstaged diff +
미추적 소스, SDK/빌드 인자, IPK/ELF SHA256, 실행 화면/배치, 자동 실행 drop-in을
대조한다. AOT 파일은 Dart 원본 소스가 아니다. #10의 과거 배포 문서 경로를
현재 장치에 존재하는 1.2.0 원본이라고 가정하지 않는다.

## 적용 전 검토와 복원 절차 — 아직 실행 금지

1. 사용자 승인 후 현재 정상 앱 패키지/앱 디렉터리, 실제 앱 계정 데이터,
   `.previous`, systemd unit/drop-in, launcher, RPi4 ELF·참조·모델·실행 스크립트를
   날짜별 비공개 보관 위치에 복사한다. symlink/owner/mode와 SHA256을 검증한다.
2. Flutter/ATLAS build와 ABI 결과, 고정 커밋/필수 자산 및 독립 source export를
   검토한다. PR #9/#10은 이 UI 후보와 별도 승인·기기 확인 단계다.
3. 실행 중 앱과 카메라 소비자를 확인한다. `safehub-ui.service` launcher 중지와
   AppManager의 실제 앱 종료는 다르며, 중복 앱이 카메라를 점유하지 않게 한다.
4. 사용자가 명시적으로 적용을 지시하면 확인된 PackageManager 설치 방식으로
   **같은 앱 ID**를 갱신한다. Uninstall/ClearAppData로 설정을 없애지 않는다.
   읽기 전용 rootfs를 임의로 쓰기 전환하거나 bootstrap 설치를 선행하지 않는다.
5. 적용 뒤 실행 ELF/IPK/manifest 버전, 배치·주소 설정 보존, 단일 카메라 연결,
   실 STT 복귀, MQTT 재연결과 물리 LED/진동/커튼 동작을 따로 확인한다.
   오류·터치 응답과 실제 재부팅 복귀도 승인된 장비 창에서 검사한다.
6. 복원이 필요하면 후보만 중지하고 검증한 이전 package/앱 디렉터리와 원래
   실행 설정을 복구한다. downgrade가 거절되면 앱 제거로 우회하지 않는다.
   사용자 최신 배치를 먼저 별도로 보존하고, 앱 계정 owner/mode를 유지한다.
   실행 파일 해시·버전·배치와 카메라 점유를 다시 대조한다.

구 앱/GRU/중복 실험 폴더 정리는 사용·의존성·개인 작업 여부가 확정된 후 별도 diff로
제안한다. 이번에는 기존 PR 닫기/삭제, main/develop 직접 반영, 장치 실행본 교체 또는
보드 플래시를 하지 않는다.
