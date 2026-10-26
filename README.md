# SafeHub · 멋쟁이들

2026 임베디드소프트웨어 경진대회 LG전자 부문 팀 프로젝트입니다.
현재 통합 후보의 UI 진입점은 **[SW/safehub_scenario](SW/safehub_scenario/README.md)** 하나입니다.
PR #10의 새 화면·장치 제어, #6의 필요한 안정화, #9의 수어 수정 소스를
[기존 Draft PR #11](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/pull/11)에서 검토합니다.
#10은 #8/#7을 포함합니다. 사용자가 여섯 권장안을 승인해 옛 UI와 독립 과거 앱은 정리했습니다. main/develop에 병합하거나 실제 장치에 배포한 상태는 아닙니다.

## 시작하기

저장소 루트에서 실행합니다. 출력·SDK·개인 설정·모델은 저장소 밖에 둡니다.

```sh
# Flutter 없이 소스 패키징과 화면 미리보기 준비만 검사
python3 -m unittest discover -s SW/safehub_scenario/tool -p 'test_*.py' -v
python3 SW/safehub_scenario/tool/run_ui_preview.py --check-only

# 전체 새 UI의 소스·테스트를 호스트용 새 폴더에 준비
python3 SW/safehub_scenario/tool/prepare_host_tests.py /tmp/safehub-scenario-host
```

Flutter SDK가 준비되어 있다면 생성한 호스트 폴더에서 `flutter pub get` 후
`flutter test`를 실행합니다. 호스트 복사본은 ATLAS 전용 path 플러그인 두 개만 제외하며
현재 UI의 Dart 소스·테스트·자산을 그대로 사용합니다. 옛 UI나 CSI 서비스 폴더의 도우미를
가져다 쓰지 않습니다. [브라우저 미리보기](SW/safehub_scenario/docs/scenario-event-overlays.md)와
[Windows 호스트 준비](SW/windows_preview/README.md)는 개발용입니다.
ATLAS runner·manifest는 `SW/safehub_scenario/atlas`에 있습니다.

## 현재 구성과 정리 범위

| 경로 | 역할 |
|---|---|
| `SW/safehub_scenario` | 현재 UI, 자체 runner·record_atlas·자산·테스트·호스트 도구 |
| `SW/rpi4_sign_cpp`, `SW/rpi4_vision_atlas` | #9 수어/비전 소스 후보, 실제 장치 실행은 미검증 |
| `SW/rpi5_hub`, `SW/uno_bridge` | 수어 단축키, MQTT·Uno 경보/팬/커튼 명령 경로 |
| `SW/local_stt`, `SW/fasttext_context` | 음성 자막 서비스, fastText 문맥 서비스 소스 |
| `SW/atlas_boot` | 현재 Scenario 앱 ID를 사용하는 부팅 구성 후보 |
| `SW/wifi_sensing` | 제품은 상태·기존 모델 선택·추론 전용. 수집·학습은 개발용 |
| `HW/esp32_csi` | 현재 C6 송수신 소스·라이선스. 빌드/플래시 미실행 |
| `SW/windows_preview` | 현재 UI의 Windows 개발 호스트·패키징 도구 |

옛 `SW/safehub_app`, 독립 CSI 데스크톱 앱, 모의 Pi4 비전, 생성형 서버는 제거했습니다.
수어 회귀에 필요한 기준 코드/fixture와 개발 도구는 구분해 남겼습니다.
[최종 제품 범위·검증·복원 절차](docs/integration/product-scope-20261027.md)를 확인하세요.
정리 전 코드는 [GitHub 백업 브랜치](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/tree/backup/pr11-before-product-cleanup-20261027)에서 되돌릴 수 있습니다.

브라우저 미리보기는 기본적으로 제품 화면입니다. `--developer-tools`를 추가한 경우만
시나리오/장치 시험과 CSI 수집·학습 화면을 표시합니다. 실제 연결용 빌드에서도 기본은
`SAFEHUB_DEVELOPER_TOOLS=false`이며, 개발 도구 노출과 실제 I/O 허용은 서로 다릅니다.

## 버전과 검증 근거

앱 ID는 `com.atlas.app.safehub_scenario_pr7`, Dart package와 실행 파일 이름은
`safehub_app`입니다. 이 이름은 옛 UI 디렉터리와 구별해야 하며 일괄 치환하지 않습니다.
1.2.0은 과거 사용자 확인, 1.4.0 설치는 #10 작성자 보고입니다. 소스 후보는 1.4.0+1이며
현재 장치 실행본·IPK·설정·보관본은 이 클라우드에서 **미확인/미확보**입니다.

새 UI 전체 Flutter 271 pass / 0 fail / 1 opt-in 실제 fastText skip,
통합 C++ 19개 통과 등 [검증 근거와 제한](docs/integration/pr10-addendum-review.md)을 확인하세요.
정적 분석은 error 0 / warning 0 / info 103, exit 1입니다.
호스트 결과로 ATLAS 빌드·재부팅·실제 모델·마이크·물리 장치 검증을 주장하지 않습니다.

## 계약과 자료

- [MQTT 계약](config/topics.json): 기존 topic·JSON·QoS·retain을 유지합니다.
- [CSI 서비스](SW/wifi_sensing/README.md), [이전 독립 CSI 개발 도구](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/blob/d6be7c7f74a4e715cff73979f2a5d16c1cb31d0c/WiFi-CSI-Sensing/README.md): 모델/전처리 버전을 혼용하지 않습니다. CSI의 전역 MQTT 사건 발행은 미완료입니다.
- [Home Assistant·ThinQ 상태](docs/home-assistant/STATUS.md): 미완료 연동을 작동 기능으로 표시하지 않습니다.
- [협업 규칙](CONTRIBUTING.md): 작업 브랜치·Draft PR에서 검토하고 main/develop에 직접 반영하지 않습니다.

서드파티 고지·라이선스는 각 모듈과 `third_party`에 유지합니다. SDK·빌드 산출물·
개인 CSI 기록·인증정보·녹음·설정·모델 보관본은 Git에 무차별로 추가하지 않습니다.
