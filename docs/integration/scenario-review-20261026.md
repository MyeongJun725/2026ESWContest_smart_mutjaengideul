# SafeHub Scenario 통합 후보 검토 — 2026-10-26

이 브랜치는 **검토용 후보**다. 전체 통합·실기 검증 완료가 아니다.
사용자가 확인한 RPi5 기준은 PR #8 기반 **1.2.0**, 앱 ID는
`com.atlas.app.safehub_scenario_pr7`이다. ID의 `pr7`로 소스 버전을 추론하지 않는다.
새 장치 테스트 창은 현재 사용자 기준에 미적용이며 이 후보에 포함하지 않았다.

## 작업 환경과 보존

- Debian 13 x86_64 클라우드, Bash, Python 3.12.14, GCC 14.2.0.
- 원래 체크아웃: `/workspace/2026ESWContest_smart_mutjaengideul`, `develop`.
  시작 당시 tracked diff, staged diff, 미추적 파일 모두 없었다.
- ignored 파일과 `.git`을 포함한 전체 보존본:
  `/workspace/.cloud-setup/preservation-20261026/original-checkout.tar.gz`.
  953개 항목 및 Git HEAD/Scenario 원본 포함을 검사했다.
  SHA256: `0ffbf4487b9480e69d28054a86f8edae41af3c5a19e7c0cc2312180c50e0d209`.
  별도로 status, binary diff, staged diff, untracked/ignored 파일 목록을 보존했다.
- 수정용 worktree: `/workspace/safehub-integration`.
  PR #9/#10은 각각 별도의 읽기/호스트 검토 worktree에서 검사했다.
  이 보존 범위는 클라우드에 실제 존재하는 파일이다. 다른 PC의 미커밋 Pi5/GRU
  작업이나 장치 설치본을 확보했다고 주장하지 않는다.
- 이번 작업에서 장치 연결·서비스 제어·앱 교체·펌웨어 플래시는 실행하지 않았다.

## 고정한 Git/PR 상태

Git ref와 GitHub 웹 페이지를 대조했다. #6/#8/#9/#10은 모두 open Draft,
base `develop`이다. 웹 페이지 Reviewers에는 `No reviews`가 표시됐다.
CI/required-check 상세는 GitHub API의 네트워크 거부 때문에 확인하지 못했다.
`Checks` 탭의 존재나 작성자의 테스트 설명을 CI 성공으로 간주하지 않는다.

| 대상 | 검토 SHA | 문서 이후 차이 / 결정 |
|---|---|---|
| main | `40551d781e19a8e7974be47334ef4132d1ed4d1d` | 인계 문서와 동일; 변경하지 않음 |
| develop | `3ecfa82eff1d2c96118d5015697ac34455ec95a3` | 동일; 추가 필수 변경 없음 |
| #6 | `7061b35dbcfe5200d80311799b8509fbc13e4df8` | 동일; 공통 조상 `9cef383c7d5cb445169df1208fa155833de65a68`부터 기능별 이관 |
| #8 | `9037ac901b0ef16a67a4b7a9d519a7d46d18de1e` | 동일; UI 출발점. #7 `64e60df`가 조상에 포함됨 |
| #9 | `ae887ac277bb0e3fc95ad4dc766f678b29bb9876` | 동일; 별도 RPi4 후보로 유지, 이 UI 브랜치에 병합하지 않음 |
| #10 | `da7248fac4c00f92f7a9a4fa265c733c9e73f765` | 새로 수신. MyeongJun725 / Choi Myeongjun. #8 이후 `a5c910b`, `91f510f`, `da7248f` 3개 추가 커밋 검토 |

#10의 head는 `MyeongJun725:feature/uno-actuator-bridge`, #8의 자손이다.
따라서 #10 전체 적용은 미배포 장치 창과 자동 물리 명령 경로까지 가져온다.
이번 후보는 #8 화면과 #6 안정성 이관을 우선하고 #10은 별도 검토로 남겼다.
#10의 문서에 있는 1.3/1.4 설치·UART 시험 기록은 **작성자 보고**다.
사용자 확인 기준 1.2.0을 그 기록으로 조용히 교체하지 않았다.

## 채택한 변경과 보류

| 기능 | 채택 내용 | 검증/한계 |
|---|---|---|
| 재현 소스 | `SW/safehub_scenario` 유지. 기존 runner를 이 경로에 복사하고 ID/entry/CMake를 일치시킴 | 기존 템플릿 출처 명시. 실제 설치 IPK와 일치 확인은 미완료 |
| 버전/추적 | pubspec `1.2.0+1`, manifest `1.2.0`, 새 `lib`/record plugin ignore 예외 | 번호는 사용자 기준과 정렬한 후보 표기. 설치본 재현 증거가 아님 |
| STT | reload 뒤 systemd `LoadState=loaded`인 로컬 unit 시작 | `/data` 고정 경로 대신 systemd의 실제 탐색/override를 따름. stub 4개 통과 |
| MQTT | 안전 ID FIFO 최대 2000, 공백 정규화, 잘못된 ID/JSON 복구, no-ID 호환; listener→subscribe, 수어 QoS 1 | #8의 packet-header 기반 수어 재전송 억제/lifecycle 보존. 새 Dart 회귀는 SDK 확보 후 실행 필요 |
| 카메라 | 연결 상태마다 generation 갱신, 비연결 프레임 거절, 늦은 decode 폐기, decoder 주입 | ValueNotifier와 contain 화면 유지. 단절/재연결/dispose 회귀 작성, 실행 대기 |
| 오디오 | 첫 재생까지 native player 생성 지연, stop/play/dispose 대기 제한, dispose 중 늦은 play 거절 | Future timeout은 native 동기 호출을 취소하지 않음. ATLAS 응답성/권한 실기 필요 |
| 실행 도구 | 시작/설치 전제의 기본 ID 및 Windows 원본 경로를 Scenario로 정렬; 기존 앱 ID는 환경변수로 선택 가능 | 배포 스크립트는 실행하지 않음. Windows 호스트 도구 11개 통과 |
| 테스트 | 옛 119 모달/문구 테스트를 현재 도움 화면/미전송 문안에 맞춤 | 안전 우선순위·취소·중복·사건 초기화 검사를 유지. 실행 통과로 표시하지 않음 |
| CSI adapter | #6 offline adapter는 **보류** | 독립 Python 8개 통과. 모델/serial/MQTT 발행/사건 확인을 연결하지 않는 오프라인 봉투 변환기임 |
| #6 서식 변경 | 채택 제외 | manifest/hurt expected/ranking 3개 JSON의 파싱 값이 같음을 이번에 재확인. 모델 변경 아님 |
| 중복/옛 코드 | 유지 | 구 앱/GRU/실험 폴더는 남은 도구·문서 의존성과 사용자 자산 대응이 확정되지 않아 삭제하지 않음 |

`config/topics.json` 1.2는 **검토 후보 명세**로, 기존 topic/key/type을 유지하고
현재 C++ translation/절대 전원 경로와 legacy GRU 경로를 구분했다.
live CSI 낙상 경보 통합 또는 장치 물리 확인이 완료됐다는 뜻이 아니다.

## 이번에 직접 실행한 검증

| 대상/고정 SHA | 이번 결과 | 범위 |
|---|---|---|
| 통합 후보 boot | 4/4 통과 | systemctl stub만 사용; 로컬 unit/외부 STT/reload·조회 실패 |
| 통합 후보 source packaging | 3/3 통과 | ID/manifest/CMake 일치, ignore 예외, 모든 Scenario 소스/테스트/자산의 host 사본 일치와 덮어쓰기 거절 |
| 통합 후보 Windows helper | 11/11 통과 | Python 준비·패치/패키징 도구; Windows 앱 빌드는 아님 |
| 통합 후보 preview preparation | 통과 | `--check-only`; Flutter 컴파일·화면 검증 아님 |
| #6 offline adapter `7061b35` | 8/8 통과 | 정규화·사건 재무장/ID, 보류 모듈의 독립 검사 |
| #9 `ae887ac` CMake/CTest | 19/19 통과 | GCC 14.2, CMake 3.31.6, Release + assertion 활성, x86_64 core compile/link/runtime |
| #9 `ae887ac` Python diagnostics | 3/3 통과 | 수집 진단 도구; 카메라 실행 없음 |
| #10 `da7248f` Uno/shortcut | 14/14 통과 | 합성 monotonic/serial write 계약, 커튼·절대 전원·중복·만료 |
| #10 `da7248f` context classifier | 6/6 통과 | 가짜 모델/문맥 규칙. 실제 fastText 모델 정확도 아님 |

실행 명령은 [재현·적용 준비](scenario-reproduction-20261026.md)에 있다.
클라우드 로그는 `/workspace/.cloud-setup/`의 `pr9-cmake-*.log`,
`pr9-sign-ctest.log`, `pr9-sign-ctest.xml`, `pr10-uno-tests.log`,
`windows-tools-tests.log`에 보존했다. 이전 onboarding의 CSI 52개 통과는
이 표에 합산하지 않았다. 서로 다른 PR/환경의 검사 수를 하나의 통합 통과 수로 합치지 않는다.

### 아직 실행하지 못한 필수 확인

- Flutter SDK가 없고 공식 SDK 서버 `storage.googleapis.com`이 네트워크 정책에서
  거부된다. 새/기존 Scenario Dart 테스트, formatter, analyzer 및 앱 빌드는
  **이번 실행 미검증**이다. 정적 분석 warning/info/error 개수도 측정하지 않았다.
  SDK 접근을 확보한 후 새 host 폴더에서 전체 suite를 실행해 미해명 실패를 해결해야 한다.
- 앱 ID만으로 배포 소스 대응을 확정할 수 없다. 실제 1.2.0 소스/runner/manifest,
  빌드 인자·SDK, IPK/ELF 해시, 실행 계정 배치와 `.previous`, drop-in은 미확보다.
  `defaultDashboardLayout()`은 #8 값으로 유지했으며 이를 승인된 실제 배치라고 부르지 않는다.
- GitHub API `api.github.com` 접속 거부로 상세 CI와 Draft PR 생성은 외부 전제다.
  API와 SDK 도메인 허용 초안은 저장했지만, 설정 저장/런타임 적용이나 게시를 했다고 주장하지 않는다.

## #9 ARM64 결과 해석

`word1229-portable-abi.json`과 빌드 스크립트를 읽었다. 저장소 보고서는
ARM64 전체 빌드/링크와 정적 ABI 성공(`passed=true`), 후보
`5c14f1fc0d7741417b46299b8ad010054ee509167eeda16c7a9b7a48e34d775c`,
AArch64 ELF64 little-endian, interpreter `/lib/ld-linux-aarch64.so.1`,
13개 장치 라이브러리/로더 해시 일치를 기록한다.
`target_execution_performed=false`, `deployed=false`도 명시돼 있다.

이 클라우드에는 `build/portable-pr9`, 대상 라이브러리 수집본, 후보 ELF,
고정 교차 sysroot/헤더가 없어서 이 **ARM64/ABI 실행을 독립 재현하지 못했다**.
호스트 19개 통과는 별도 결과다. 2개 선택적 OpenCV/ORT geometry 검사 및 live
vision translation unit의 추가 빌드는 구성하지 않았다.
카메라/모델 초기화, 지연, 실제 WORD1229·정상 한 손 오차단률, MQTT 실동작은 미검증이다.
2250ms는 느린 관측의 종료 임계값이지 실시간 최대 종료 지연 보장이 아니다.
이 후보는 별도 PR #9로 유지해 ARM64 산출물과 장치 검증을 섞지 않는다.

## #10 Uno 수신 항목과 남은 계약

- PR은 **수신·검토됨**. Uno→LED D9 / 진동 D6 / 팬 D5 / 커튼 D7·D8,
  9600 baud의 기존 단문자 프로토콜용 Python 어댑터다. ESP32 CSI 펌웨어가 아니다.
- `SW/uno_bridge`와 기존 shortcut hub 변경, 선택적 context 서비스,
  장치 테스트 창/자동 경보 경로가 함께 들어 있다. #6 일부 이관도 중복돼
  전체 cherry-pick 대신 이번 UI 후보의 기능 이관과 별도로 평가했다.
- `.ino`/Uno 빌드 manifest/Arduino 라이브러리 버전은 **미수신**이다.
  기존 C6 PlatformIO 파일로 Uno 컴파일을 대신하지 않았다.
- 명령은 QoS 1/retain false. 경보 ID·timestamp/최대 duration과 256개/300초
  process-local 캐시, 재연결 시 재구독, 커튼 2초 만료/역방향 정지/대기 로직을 확인했다.
  serial echo는 명령 처리 경로의 증거이며 LED/모터/진동의 물리 완료 ACK가 아니다.
- 원본 스케치에는 통신 단절 watchdog이 없다는 작성자 설명이 있다. 어댑터가 죽었을 때
  10초 자동 정지를 펌웨어가 보장한다고 표시하지 않는다. 재시작 팬 OFF, 명령 지연/재생,
  USB 초기화 중 명령 수명과 실제 종료/취소는 장치에서 별도 검증할 항목이다.
- 이 UI 후보에는 #10의 자동 물리 출력·커튼 UI·장치 테스트 창을 넣지 않았다.
  firmware 출처/해시·보드 버전과 실제 실행본 대응을 확보한 뒤 별도 선택한다.

기존 #6/#8/#9/#10은 닫거나 병합하지 않았다. #6을 대체했다고 닫는 판단은
새 UI 전체 회귀와 실기 항목이 끝난 후 사용자가 한다.
