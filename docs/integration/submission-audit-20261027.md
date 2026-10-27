# 제출 전 추가 점검 · 2026-10-27

사용자가 남은 34시간 동안 README·현재 통합 코드와 미사용 소스를 자율적으로 정리하도록
지시한 후 진행했다. 기존 PR #11과 제품 범위 여섯 권장안, 실제 장치/main/develop 변경 금지를 유지했다.
시작 HEAD는 `82494552e7bc44cffc45022cb9ea6dc68707b967`, 작업 파일은 깨끗했다.

## 보존과 현재 진입점

- [추가 GitHub 백업](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/tree/backup/pr11-before-submission-audit-20261027)은
  시작 SHA 8249455를 보존한다. 이전 [정리 전 백업](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/tree/backup/pr11-before-product-cleanup-20261027)
  d6be7c7과 847개 파일 복원 근거도 유지한다.
- `/workspace/.cloud-setup/submission-audit-20261027/before-audit.bundle`에 시작 상태를 보존했다.
  SDK/기록/모델/개인 설정을 새로 만들거나 지우지 않았다. 별도 임시 호스트와 최소 검사 venv는
  기존 환경을 보존한 채 CI 재현용으로 준비했다.
- 현재 제품 원본은 `SW/safehub_scenario` 하나다. [README](../../README.md)를 제품 기능·화면 실행·
  검사·소스 위치 순서로 다시 정리했고 [제출 확인 안내](../SUBMISSION.md)를 추가했다.
  main이 제출 대상으로 지정돼 있다면 PR 브랜치 push와 최종 병합은 별도 단계다.
  fastText/Uno 모듈의 현재 검사·모델 의존성·staging 안내도 보완했다. 이전 Windows SDK 조합과
  #10의 핀/설치 보고는 현재 코드·직접 장치 확인과 구별하도록 표시했다.

## 실제 수정

| 발견/검토 | 수정과 근거 |
|---|---|
| Python에서 줄바꿈을 먼저 공백으로 바꿔 훈련 뒤 실제 화재 문장이 같은 절로 합쳐짐 | 규칙 입력의 LF/CRLF/CR 경계를 보존하고 native fastText 입력만 한 줄로 변환 |
| Dart에 오보/CR 경계 처리가 Python과 다름 | 공통 JSON 20사례로 두 경로 검사. 부정/훈련/예방/오보와 실제 위험의 독립 문장을 구별 |
| 재연결 후 수어 packet ID 재사용과 이전 cache 충돌 | UI와 sign_hub의 clean-session cache 초기화. 세션 안 DUP 억제와 안전 message_id의 세션 간 중복 방지는 유지 |
| 새 호스트마다 의존성이 다시 풀릴 수 있음 | 검증한 host_pubspec.lock을 test/browser/Windows 호스트에 복사. Flutter 3.35.7 / Dart 3.9.2, enforce-lockfile 검사 |
| 폰트 고지가 번들 asset에 빠지고 runner의 LICENSE 참조 파일이 누락됨 | 기존 OFL 파일을 바이트 그대로 보존해 asset에 포함. runner 공식 upstream BSD 원문과 CMake 동봉 규칙 추가. upstream commit·URL·원문/로컬 SHA256 기록 |
| 미사용 06ct 웹캠 실행 파일이 삭제한 모의 비전 모듈을 import함 | 사용처 검색 후 제거. 실제 exporter/offline 참조가 있는 07g·관련 기준 코드와 fixture는 보존 |
| 허브 test_mqtt_sender.py가 테스트 이름으로 실제 가짜 낙상 사건 발행을 수행함 | 폐기한 옛 실시간 probe를 삭제. 확인한 14개 assertion 스크립트만 Python socket 연결 차단 runner로 실행 |
| 수어 FrameHands Python 검사의 import 경로가 일반 discovery에서 실패함 | 검사 모듈 경로를 명시하고 NumPy 검사 의존성을 고정. FrameHands+진단 22개 통과 |

### 실시간 probe 실행에 대한 기록

허브 검사 대상을 확장하던 초기 실행에서 `test_mqtt_sender.py`가 실제 publish 함수에
진입했다. `raspberrypi5.local`의 DNS 해석에서 실패했으며 브로커 연결·패킷 발행은 이루어지지 않았다.
이 실패를 소프트웨어 검사 통과로 세지 않았다. 해당 미사용 파일을 삭제하고
`tools/run_hub_checks.py`에서 승인 목록만 실행하도록 고쳤다. runner는 subprocess의
Python socket 연결/DNS 함수를 차단한다. 이를 우회 불가능한 보안 sandbox라고 주장하지 않는다.
별도의 회귀 검사로 연결 시도가 실제 socket I/O 전 차단되는 것을 확인했다.

### 라이선스 파일 대응

Pretendard OFL 원문은 이미 저장소에 있었다. upstream과 비교했을 때 끝 공백 한 개 차이뿐이므로
기존 파일을 덮어쓰지 않고 보존했다. 새 metadata에는 로컬/공식 원문 해시를 각각 기록한다.
폰트는 앱 assets에, runner BSD 파일은 native bundle의 licenses 폴더에 포함하도록 했다.
라이선스 본문이나 기존 저작권 주석을 바꾸지 않았다. 이 조치가 ATLAS SDK 권한이나 빌드 성공을
대신하지 않는다. [고지 목록](../../THIRD_PARTY_NOTICES.md)을 참고한다.

## 직접 검증

| 범위 | 결과 | 구분 |
|---|---|---|
| 전체 현재 Flutter | **272 pass / 0 fail / 1 skip** | skip은 실제 fastText 서버·모델 opt-in |
| Python 문맥/HTTP | **9/9** | 실제 모델 정확도 아님. 규칙·HTTP에는 fake 모델 주입 |
| Uno/단축키 계약 | **15/15** | 새 clean-session callback 검사 포함, 실제 MQTT/USB 아님 |
| 수어 FrameHands·진단 Python | **22/22** | NumPy 1.26.4, JSON/배열 변환·진단 |
| 현재 UI 소스/라이선스/호스트 패키징 | **6/6** | 제품 원본·자산 일치, 단독 복사본, 출력 보호, 고지 해시 |
| Windows Python 도구 | **14/14** | Windows native 빌드/실행 아님 |
| 부팅 stub | **4/4** | host systemctl 호출하지 않음 |
| 허브 runner 차단 회귀 | **1/1** | socket 연결을 시도하는 임시 fixture가 차단됨 |
| 허브 assertion 스크립트 | **14개 실행 통과** | unittest 개수로 합산하지 않음; 11개 shortcut + 3개 hub |
| C++ CMake/CTest | **19/19** | 아래 CI 명령을 최소 환경에서 재현, host x86_64 |
| 제품 web release | **exit 0** | preview=true/developer-tools=false, 실제 장치 연결 없음 |
| strict 분석 | **0 error / 0 warning / 103 info, exit 1** | 기존 스타일 안내 유지 |
| CI 분석 명령 | **exit 0** | --no-fatal-infos; error/warning은 여전히 fatal |
| workflow actionlint | **exit 0** | 공식 1.7.12 배포 checksum 확인 후 검사 |

처음 shared-corpus 검사는 줄바꿈 관련 4개 실패를 재현한 뒤 수정했다.
최소 CI 환경 재현 중 발견한 packaging 의존성 누락과 FrameHands import 실패도 해결했다.
실패 기록을 삭제하거나 검사를 skip해서 통과시키지 않았다. 허브의 실제 발행 probe는 제거한
개발 잔재이므로 “그 테스트가 통과했다”고 표현하지 않는다.

최소 검사 의존성은 `tools/requirements-checks.txt`의 paho-mqtt 2.1.0, pyserial 3.5,
NumPy 1.26.4, packaging 25.0이다. 별도 최소 venv에서 workflow의 계약·부팅·Windows·허브·
C++ 명령을 그대로 실행해 모두 exit 0임을 확인했다. CSI 학습 스택/실제 모델을 가져오지 않았다.
이전에 통과한 CSI 전체 54개는 이번에 변경한 경로가 아니므로 반복 실행하지 않았다.

로그: `/workspace/.cloud-setup/submission-audit-20261027/`.
Flutter 전체 `flutter-final.log`, strict/CI 분석 `analysis-strict.log`/`analysis-ci.log`,
제품 빌드 `web-build.log`, 최소 CI 재현 `ci-contracts-replay-final.json`,
출처/도구 검사 `packaging-final.log`/`workflow-lint.log`, 허브 `hub-offline-final.log`에 보존했다.

MQTT 계약 metadata도 현재 포함된 소비자 역할과 clean-session 동작으로 맞췄다.
모든 topic 이름·QoS·retain·payload_schema는 변경 전과 같음을 비교했다.

## GitHub 검사와 남은 항목

[source-checks.yml](../../.github/workflows/source-checks.yml)은 read-only 권한으로
계약/C++ 및 고정 Flutter/제품 web 검사 두 job을 실행한다. 공식 checkout/setup-python action은
commit SHA로 고정했다. 동일 repo/branch의 PR·push 중복 실행은 최신 실행으로 모은다.
workflow 자체와 명령의 로컬 통과, GitHub-hosted 실행 결과는 구별한다.
GitHub 실행 결과는 PR #11의 **현재 head SHA에 대응하는 Checks**를 확인한다.
workflow 최초 게시 head `7c34108`의 push/PR 실행은 둘 다 success를 확인했다.
최종 문서/metadata 커밋의 현재 head 결과는 PR Checks에서 별도로 확인한다.
Actions 관리 설정 조회는 403이었으나 workflow push·실행 조회에는 문제가 없었다. 설정은 바꾸지 않았다.

1.4.0 설치는 #10 작성자 보고, 1.2.0은 과거 사용자 확인이다. 현재 설치본·IPK·ELF·모델·
장치 설정/보관본·Uno 스케치는 미확인/미확보로 유지한다. 기존 소스/Git 백업과 장치 보관본은 다르다.
ATLAS/Windows native 빌드, 실제 ARM64/ABI 독립 재현, 실제 모델·마이크·카메라·모터·재부팅·
낙상 정확도는 확인하지 않았다. main/develop 직접 반영, PR 병합/닫기/삭제, 실제 장치 서비스 제어·
실행본 교체·펌웨어 플래시는 하지 않았다.
