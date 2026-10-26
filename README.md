# SafeHub · 멋쟁이들

2026 임베디드소프트웨어 경진대회 LG전자 부문 팀 프로젝트입니다.
현재 통합 후보의 UI 진입점은 **[SW/safehub_scenario](SW/safehub_scenario/README.md)** 하나입니다.
PR #10의 새 화면·장치 제어, #6의 필요한 안정화, #9의 수어 수정 소스를
[기존 Draft PR #11](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/pull/11)에서 검토합니다.
#10은 #8/#7을 포함합니다. main/develop에 병합하거나 실제 장치에 배포한 상태는 아닙니다.

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
| `SW/wifi_sensing` | CSI 수집·학습·상태 서비스. 최종 제품에서 유지할 범위는 결정 대기 |
| `SW/windows_preview` | 현재 UI의 Windows 개발 호스트·패키징 도구 |

`SW/safehub_app`은 **옛 UI 소스**이며 새 개발/빌드 진입점이 아닙니다.
옛 UI·독립 CSI 앱·실험 코드의 최종 삭제와 화면별 기능 축소는 아직 결정 전입니다.
현재 파일을 남겼다는 이유로 모든 경로를 제품에 설치하거나 함께 실행하지 않습니다.
[완료한 정리와 사용자 결정 목록](docs/integration/ui-consolidation-20261027.md)을 참고하세요.

## 버전과 검증 근거

앱 ID는 `com.atlas.app.safehub_scenario_pr7`, Dart package와 실행 파일 이름은
`safehub_app`입니다. 이 이름은 옛 UI 디렉터리와 구별해야 하며 일괄 치환하지 않습니다.
1.2.0은 과거 사용자 확인, 1.4.0 설치는 #10 작성자 보고입니다. 소스 후보는 1.4.0+1이며
현재 장치 실행본·IPK·설정·보관본은 이 클라우드에서 **미확인/미확보**입니다.

새 UI 전체 Flutter 265 pass / 0 fail / 1 opt-in live LLM skip,
통합 C++ 19개 통과 등 [검증 근거와 제한](docs/integration/pr10-addendum-review.md)을 확인하세요.
정적 분석은 error 0 / warning 11 / info 100, exit 1입니다.
호스트 결과로 ATLAS 빌드·재부팅·실제 모델·마이크·물리 장치 검증을 주장하지 않습니다.

## 계약과 자료

- [MQTT 계약](config/topics.json): 기존 topic·JSON·QoS·retain을 유지합니다.
- [CSI 서비스](SW/wifi_sensing/README.md), [이전 독립 CSI 개발 도구](WiFi-CSI-Sensing/README.md): 모델/전처리 버전을 혼용하지 않습니다. CSI의 전역 MQTT 사건 발행은 미완료입니다.
- [Home Assistant·ThinQ 상태](docs/home-assistant/STATUS.md): 미완료 연동을 작동 기능으로 표시하지 않습니다.
- [협업 규칙](CONTRIBUTING.md): 작업 브랜치·Draft PR에서 검토하고 main/develop에 직접 반영하지 않습니다.

서드파티 고지·라이선스는 각 모듈과 `third_party`에 유지합니다. SDK·빌드 산출물·
개인 CSI 기록·인증정보·녹음·설정·모델 보관본은 Git에 무차별로 추가하지 않습니다.
