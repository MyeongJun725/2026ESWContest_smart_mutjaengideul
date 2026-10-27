> 이후 제품 범위 여섯 권장안은 승인·적용했습니다.
> [현재 제품 구성·최종 검사·복구](product-scope-20261027.md)를 함께 확인하세요.

# PR #10 추가 통합 검토 (현재 기록)

이후 UI 진입점·호스트 도구 정리와 제품 범위 결정 목록은
[2026-10-27 소스 정리](ui-consolidation-20261027.md)를 함께 참고한다.

이 기록이 이전 PR #8 중심 검토의 채택/보류 판단을 대체한다. 기존 Draft PR #11과
`integration/scenario-stability-20261026`에서 이어 작업했다. 시작 시 tracked/untracked
변경은 없었고, 직전 Git 상태를 `/workspace/.cloud-setup/addendum-preservation/before-addendum.bundle`에
보존했다. 기존 ignored 파일은 삭제하지 않았다. 원래 develop 체크아웃도 유지했다.

## 실행본과 보관본 상태

| 항목 | 근거 / 상태 |
|---|---|
| 1.2.0 | 과거 사용자 확인. 현재 실행본으로 고정하지 않음 |
| 1.4.0 및 장치 테스트 창 설치 | PR #10 작성자 보고. 이번 작업의 직접 장치 확인 아님 |
| 현재 설치 버전/manifest/IPK/ELF/배치/보관본 | 현재 클라우드에서 **미확인/미확보**. 없다고 단정하지 않음 |
| 소스 후보 버전 | pubspec 1.4.0+1 / manifest 1.4.0. 작성자 보고와 정렬한 후보 표기이며 패키지 대응 증거 아님 |
| 앱 ID | `com.atlas.app.safehub_scenario_pr7` 유지. package/executable `safehub_app` 유지 |

## 고정한 PR과 포함 관계

- #6 `7061b35dbcfe5200d80311799b8509fbc13e4df8`: 전체 병합 대신 아래 안정화 유지.
- #8 `9037ac901b0ef16a67a4b7a9d519a7d46d18de1e`: #7 포함.
- #10 `da7248fac4c00f92f7a9a4fa265c733c9e73f765`: #8 포함을 Git ancestor 검사로 확인.
  기존 #11 위에 merge하여 #8을 중복 적용하지 않음. 추가 3개 커밋의 Uno/커튼/문맥/부팅 채택.
- #9 `ae887ac277bb0e3fc95ad4dc766f678b29bb9876`: 수어 소스·회귀·빌드 도구를
  **미배포 소스 후보**로 포함. UI/Uno 경로와 충돌 없이 소스 통합.
- main/develop 및 기존 PR은 변경/병합/닫기/삭제하지 않았다.

| #6 기능 | #10과의 중복 | 최종 처리와 검증 |
|---|---|---|
| STT 부팅 | #10 고정 /data 경로 | 기존 systemd LoadState 조회 유지; fastText/sign-control도 선택적 시작, stub 4개 |
| 안전 사건 2000 ID FIFO | #10에도 구현 | 기존 정규화·no-ID 호환·잘못된 JSON/ID 회귀 유지 |
| listener→subscribe / 수어 QoS1 | #10에도 구현 | 기존 packet-header 재전송 억제/transport/lifecycle 유지, 새 장치 publish API 추가 |
| 카메라 | #10 원본 방어 미흡 | 기존 generation/연결 전후 검사/decoder 주입/ValueNotifier/contain 유지 |
| 오디오 | #10에도 lazy/timeout | 기존 dispose 중 지연 play 방지까지 유지 |
| offline CSI adapter | live 수집/발행 아님 | 보류 유지. CSI HTTP, 실제 사건 판정·정상 복귀·발행 ACK 연결은 미완료 |
| 서식/동일 JSON 모델 파일 | 기능 추가 아님 | 모델 변경으로 취급하지 않음 |

## 추가 수정

- Dart 즉시 경보와 Python `/classify`에서 훈련·부정 적용 범위를 문장 구분자로 제한했다.
  `훈련이 아닙니다. 실제 화재...`, `훈련은 취소되었습니다. 실제 화재...`는 경보 후보이며
  단일 훈련/예방/화재 부정 문장은 새 경보를 만들지 않는다. 엘리베이터 사용 금지는
  독립 화재 문장을 지우지 않는다. ASR 오류·구두점 없는 복합 문장·현장 오탐은 별도 검증이다.
- 시연이 실제 사건으로 선점된 뒤 오래된 `endScenarioTest`는 no-op이다.
  전환 콜백은 실제 경보 OFF를 발행하지 않고 새 실제 경보 제출 상태를 준비한다.
  새 부정문과 도움 취소가 기존 위험을 해제하지 않는 회귀를 유지했다.
- 장치 창의 전체 끄기에서 커튼 stop 실패를 결과에 포함했다. 라벨도 커튼 정지를 명시한다.
  10초 종료 문구는 브리지 실행 조건으로 제한한다. 창 닫기는 팬 OFF가 아니다.
- 잘못된 분류 응답 객체/HTTP 요청 구조를 거절하고 HTTP body 대기를 제한했다.
- clean MQTT 세션 연결 시 커튼 packet cache를 비워 mid 재사용을 이전 세션 재전송으로 오인하지 않는다.
- sign_hub는 배포된 `app/hub`와 clone의 `SW/rpi5_hub` 양쪽 import를 지원한다.

## 계약·설정·재현

실제 토픽/JSON은 `config/topics.json` 및 `docs/UNO_INTEGRATION.md`를 함께 본다.
수어 번역/단축키, LED/진동, aircon 절대 전원 및 curtain set_power/stop 확장을 채택했다.
모든 제어 QoS1/retain=false. 발행 성공, UART echo, 물리 완료는 다르다.
Pi4 `MQTT_BROKER`/`MQTT_PORT`와 Pi5 `MQTT_BROKER_HOST`/`MQTT_BROKER_PORT`를 혼동하지 않는다.
Mosquitto `safehub-mqtt.service`는 브로커이며 수어 라우터가 아니다.

자동 경보의 전제는 localPreview=false, MQTT 연결, actuatorsEnabled=true,
LED on/off action 설정, 지역 재난의 homeRegion(전국 예외)이다. 기본 false/빈 문자열을
자동으로 바꾸지 않았다. 시나리오의 장치 선택만으로 발행 성공을 주장하지 않는다.
실제 작동/커튼 위치 확인 ACK는 없으며 팬은 절대 전원 명령 상태다.
경보 timestamp는 과거30초/미래5초, 캐시는 topic+ID 최대256개/약300초의 프로세스 내 상태다.
커튼 2초 만료는 수신 시각 기준이며 지연된 MQTT 발행 시각 검증이 아니다.
재시작·세션 변경 뒤 강한 exactly-once 보장은 없다. 문서상 펌웨어 watchdog이 없으므로
프로세스 중단 시 10초 종료를 보장하지 않는다. 실제 스케치는 미확인/미확보다.

`python3 SW/uno_bridge/tools/prepare_deployment.py`는 파일 매핑 dry-run만 출력한다.
`--output <새로운 저장소 밖 경로>`는 소스와 service 사본/SHA256만 staging한다.
개인 배치·단축키·주소·녹음·모델은 복사하지 않으며 서비스 설치·시작·보드 접속은 하지 않는다.
clone/staging 양쪽 sign_hub import를 main 실행 없이 확인했다.
Pi5 서비스가 공유하는 `/opt/safehub-csi/python/bin/python3.12`는 CSI 정리 때 삭제하면 안 된다.

fastText는 별도 host venv에서 `CC=gcc CXX=g++`로 requirements.txt(0.9.3 / NumPy1.26.4)
빌드와 실제 import를 확인했다. 기본 Python의 clang++ 선택으로 실패한 첫 설치는
GCC 지정으로 해결했다. 이것은 ARM64 또는 `fire_screen_model.bin` 호환/정확도 검증이 아니다.
모델은 재학습/교체하지 않았다. 대상 런타임 버전·모델 SHA256·허용된 확보 위치는 미확인이다.

## 직접 검증

- 통합 Scenario Flutter 전체: **265 pass / 0 fail / 1 opt-in live LLM skip**, exit 0.
- 통합 C++ CMake/CTest: **19/19**, 진단 Python **3/3**.
- Uno/shortcut Python **14/14**, 문맥/HTTP Python **8/8**, 부팅 stub **4/4**, source packaging **3/3**.
- 허브 assertion 스크립트 **11개 실행 통과**. unittest discovery의 zero-test exit5를
  통과로 세지 않고 실제 스크립트 runner로 다시 실행했다. 실 브로커/장비 시험 아님.
- 정적 분석 error 0 / warning 11 / info 100, exit 1. #10의 불필요한 nullable 접근 경고 한 개를 고쳤다.
  preview web release 빌드는 exit 0이다. 기존 243-pass 기록은 이전 범위다.
- 로그: `/workspace/.cloud-setup/addendum-*`. 테스트는 실제 모터·MQTT 액추에이터에 접속하지 않았다.

#9 기존 보고서의 ARM64 전체 빌드/링크·정적 ABI 통과는 유지해서 인용한다.
이 클라우드의 대상 라이브러리·후보 ELF 수집본은 미확인/미확보여서 ARM64/ABI 독립 재현은
미실행이다. `target_execution_performed=false`, `deployed=false`. 카메라·모델·수어 정확도/
지연·정상 한 손 오차단은 확인하지 않았다. host 통과를 실제 장치 결과로 확대하지 않는다.

## 2026-10-27 중단 복구와 검증 대응

- 재개 시 로컬 `0e09f4ad788aaba186243c325a5d44819a734415`, 원격 #11
  `a55f263a35d4ac22171914ca716c55cb13243e4b`. 미커밋/미추적 소스와 MERGE_HEAD는 없었다.
  추가 복구 bundle·상태·로그/소스 SHA256 목록은
  `/workspace/.cloud-setup/resume-preservation-20261027/`에 보존했다.
- 위 PR refs와 main/develop은 재조회 때 동일했다. `dcf2bcb`가 #10 merge,
  `e356983`이 #9 merge, `0e09f4a`가 안전 경계 수정·검증 기록이다.
  #9 두 C++ 소스 디렉터리는 고정 PR9 SHA와 차이가 없다.
- 기존 전체 Flutter 로그 `addendum-flutter-verified.log`는 265 pass/1 skip이다.
  검사 호스트와 현재 `lib`/`test` 92개 파일이 일치한다. 전체 통과 후 nullable 경고
  한 개를 제거한 변경은 해당 사건/장치 경로 13개를 재검사해 통과했다 (`resume-flutter-affected.log`).
  후보 pubspec/manifest 버전 조정은 설치 패키지 재현의 증거가 아니다.
- fastText 최초 실패 명령: `uv pip install --python
  /workspace/.cloud-setup/fasttext-venv/bin/python fasttext==0.9.3 numpy==1.26.4`.
  CPython 3.12.14의 sysconfig CXX는 `clang++ -pthread`이나 clang++ 실행 파일이
  없었다. 패키지의 C++17 probe 실패가 `Unsupported compiler`로 보고됐다.
  setuptools의 description-file 경고는 이번 실패의 직접 원인이 아니다.
- `CC=gcc CXX=g++`로 GCC/G++ 14.2.0을 지정해 실제 native wheel 빌드 성공.
  설치 결과 fastText 0.9.3 / NumPy 1.26.4 / pybind11 3.1.0 / setuptools 84.2.1.
  실패/해결 로그는 `addendum-fasttext-install.log`, `addendum-fasttext-install-fixed.log`.
- 재현 명령: `UV_CACHE_DIR=/workspace/.cloud-setup/uv-cache bash
  SW/fasttext_context/tools/install_host.sh /workspace/.cloud-setup/fasttext-venv`.
  현재 venv에서 재실행해 의존성 호환 검사와 실제 native `tokenize` API를 확인했다.
  설치 스크립트는 저장소 밖 venv만 허용하며 서비스/장치를 제어하지 않는다.
- `tools/check_runtime.py --model <확보한 기존 모델>`은 추후 로드/분류/해시 확인용이며
  모델을 학습하거나 대체하지 않는다. 현재 작업 공간에서 `fire_screen_model.bin`은
  확보하지 못했다. 실제 모델 로드/분류/HTTP 응답과 ARM64 런타임 검증은 **미실행**이다.
  모델이 다른 장치/보관본에 없다고 단정하지 않는다.
- 설치 런타임에서 문맥/HTTP 8개를 재실행해 통과했다. 이 테스트는 여전히 가짜 모델을
  주입하므로 실제 모델의 정확도나 실제 모델 HTTP 검증으로 세지 않는다.
  설치 스크립트와 시작 안내는 기존 CSI 설정을 보존하여 환경 설정 초안에도 저장했다.
  저장은 새 환경에서의 복원·실행이나 게시를 입증하지 않는다.
  런타임 probe·설치 로그: `resume-fasttext-runtime.log`; 규칙/HTTP: `resume-context.log`.

## 장치 자료를 확보할 단계의 일괄 체크리스트

1. AppManager GetInfo/GetStatus와 설치 manifest/패키지 SHA256, 실제 실행 ELF, 빌드 소스
   commit+미커밋/미추적 소스, SDK/runner/plugin/빌드 인자를 함께 확보한다.
2. 실제 앱 계정 HOME/USERPROFILE의 ui-layout.json/.previous와 소유권·hash, 연결/단축키
   설정을 비공개 보존한다. Git에는 필요한 배치 숫자만 선별한다.
3. systemctl show의 FragmentPath/DropInPaths/ExecStart로 launcher와 실제 앱,
   Mosquitto와 라우터, 카메라 소비자 중복을 구분한다. 최종 재부팅 복귀는 미검증이다.
4. Uno .ino/보드·라이브러리 버전/핀/UART FVLs 응답·1.5초 제한·watchdog의 실제 소스를 확보한다.
5. fastText 모델의 출처·버전·해시·사용 허용 경로, 대상 Python/package 버전을 확보한다.
6. #9 대상 런타임 수집본·로더13개 해시·후보 ELF와 현재 실행본 대응을 확보한다.

그 뒤에만 기기 전용 빌드/실험 계획을 확정한다. 기존 적용/복원 절차의 백업·동일 앱 ID·
설정/owner 보존·downgrade 거절 시 제거 금지 원칙을 유지한다. 실제 설치·재부팅·펌웨어
플래시는 사용자 후속 지시 전에는 하지 않는다. 최종 merge도 보류한다.
#6은 기능 이관·기기 확인 뒤 닫기 후보일 뿐 현재 닫지 않는다. #7/#8은 #10과 #11에 포함된다.
#9/#10 원본 PR도 유지하며 최종 develop→main 후보는 검증 상태를 드러낸 별도 검토를 거친다.
