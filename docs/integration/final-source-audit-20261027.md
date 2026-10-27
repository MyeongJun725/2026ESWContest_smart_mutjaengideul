# 현재 통합본 소스 완전성·미사용 코드 점검 · 2026-10-27

## 판단

현재 공개 PR #7/#8/#9/#10 head의 변경은 #11에 포함돼 있다. #6은 필요한 안정화를
선택 이관했으며 전체 PR을 병합한 상태가 아니다. 알려진 공개 수정 누락과 장치 전용
자료 미확보를 구분한다. **현재 GitHub 소스만으로 운영 장치 전체를 그대로 재현할 수
있다고 선언하지 않는다.** 운영 바이너리의 소스 대응·펌웨어·모델·현재 배포 상태가 남아 있다.

점검 시작은 `6ed93d5af841503426750119b2245ec3091a3964`, UI 정리 커밋은
`10d14325830b5a66a801568c46ec5549e5a79108`이다. 시작 상태는 clean이었고
`/workspace/.cloud-setup/final-source-audit-20261027/before-audit.bundle`에 전체 이력을 보존했다.
main/develop과 기존 장치 실행본은 변경하지 않았다.

## 최신 원격과 포함 관계

GitHub PR 목록과 원격 브랜치 전체를 다시 조회해 별도 audit remote refs로 읽었다.
기존 작업 브랜치를 바꾸거나 main/develop에 적용하지 않았다. #11 이후 새 PR은 조회되지 않았다.

| PR | 조회한 최신 head | 확인 |
|---|---|---|
| #6 | `7061b35dbcfe5200d80311799b8509fbc13e4df8` | STT/record_atlas·부팅, MQTT ID/구독 순서, 카메라 generation/dispose, lazy audio/timeout 선택 이관. 전체 ancestor 아님 |
| #7 | `64e60df56be869a5d1681e7c492a6c29633eae7b` | ancestor, #10에 포함 |
| #8 | `9037ac901b0ef16a67a4b7a9d519a7d46d18de1e` | ancestor, #10을 통해 포함. 중복 적용 없음 |
| #9 | `ae887ac277bb0e3fc95ad4dc766f678b29bb9876` | ancestor. 두 수어/비전 디렉터리의 제품 소스는 동일. 차이는 Python adapter 검사의 import 경로 보완뿐 |
| #10 | `da7248fac4c00f92f7a9a4fa265c733c9e73f765` | ancestor. Uno controller 유지, retain/DUP 처리와 staging 보완 유지 |

`feature/SW`, `feature/rpi4-live-sign-mqtt`, 두 camera perf 브랜치 및 입력 좌표 보정
브랜치도 비교했다. 별도 역사에 있는 `993a103`의 좌표 bridge와 MQTT 연결 유지 로직은
현재 코드에 보존된다. `feature/sign-shortcut-control`의 `a623b3b`은 과거 단축키
프로토타입이며 후속 저장/복원/허브 통합이 현재 코드에 있다. 조상 SHA가 다르다는 이유만으로
옛 프로토타입을 추가 병합하지 않았다. `feature/HW`의 과거 ESP32 실험 UI/다른 펌웨어도
현재 C6 소스에 무조건 합치지 않았다.

## 미사용으로 확인해 제거한 것

`lib/main.dart`부터 explicit import/export/part를 순회했다. 정리 전 Dart 45개 중
9개가 연결되지 않았고, 저장소 전체 참조 검색으로 현재 제품의 호출이 없음을 추가 확인했다.

- 옛 카드·경보 화면 8개: `event_display.dart`, `disaster_card.dart`, `disaster_overlay.dart`,
  `emergency_overlay.dart`, `recent_events_card.dart`, `safehub_card.dart`, `safety_card.dart`, `sign_card.dart`.
- 별도 파일 녹음 서비스 `voice_recorder_service.dart`와 그 전용 검사 18개.
  현재 마이크는 `LiveCaptionService`의 PCM 스트리밍 및 파일 업로드용 분할 WAV 경로를 사용한다.
  `record_atlas`, 녹음 패키지와 STT fallback은 유지했다.
- 현재 소스에서 참조하지 않는 배경 PNG 2,041,018 bytes 및 pubspec asset 선언.
- 옛 카드에서만 쓰던 재난 배경색/강조색/아이콘 helper 3개. 현재 경보의 severity 판정은 유지.

CSI disconnect 중 재난 응답 검사는 옛 DisasterOverlay 대신 실제 ScenarioEventOverlay로
옮겼고 800×480/1920×1080 모두 통과했다. 새 화면 원문에는 지역/시각이 포함되므로
정확히 같은 문자열을 요구하던 첫 실행 2개 실패를 `textContaining`으로 바로잡았다.
실패 검사를 삭제하거나 skip하지 않았다.

정리 후 **Dart 36/36 reachable, missing local import 0, missing declared asset 0**이다.
`python3 tools/audit_product_sources.py`로 재확인하고 CI에서도 실행한다. 누락 import,
미사용 파일, 누락 asset, 조건부 import를 주입한 도구 검사 4개도 추가했다.
이는 파일 단위 정적 연결 검사이며 모든 공개 함수의 사용 여부나 runtime coverage를
증명하지 않는다. 개발 모드 전용 파일도 명시적인 소스 연결에 포함된다.

## 사용 중이어서 유지한 것

| 소스/자료 | 유지 이유 |
|---|---|
| 현재 scenario UI 36개 | 홈·자막·카메라·경보/도움·팬/커튼·단축키·CSI·설정·문맥 서비스 |
| `record_atlas` | 실제 PCM 마이크 경로. 옛 VoiceRecorderService 삭제와 별개 |
| `SW/local_stt` | 로컬 한국어 자막 서버·모델 다운로드 규격 |
| `SW/fasttext_context` | 현재 문맥 API. 실제 모델은 별도 준비 |
| `SW/uno_bridge`, `SW/rpi5_hub` | USB 명령·단축키 저장·MQTT 라우팅 |
| 수어 C++/live ONNX 소스 | #9 추적·복구·비동기 MQTT·추가 참조 경로 |
| frozen Python/diagnostics/fixture | C++ 포팅 parity와 회귀 재생·fixture 생성의 기준. 제품 실행 진입점 아님 |
| MediaPipe adapter/Bazel 자료 | 과거 포팅·대조용 경로. 현재 ONNX live 및 기본 CMake 검사에서는 제외. 외부 MediaPipe 의존 |
| CSI runtime/수집·학습 | 현재 추론과 같은 모델/전처리 호환 및 별도 개발 모드. 제품 서비스는 inference-only |
| Windows/브라우저 도구 | 장비 없는 검토/개발용. 실제 ATLAS 제품 배포본과 구분 |
| C6 송수신 소스·고지 | 별도 보드의 필요한 펌웨어 소스. 보드 빌드/플래시 미실행 |
| 과거 light binding/parser | 사용자 저장값·기존 wire 호환 보존. 일반 제품의 활성 light 제어로 노출하지 않음 |

옛 `SW/safehub_app`, 독립 `WiFi-CSI-Sensing`, mock `SW/rpi4_vision`, 생성형 서비스
`SW/safehub_scenario/llm`은 현재 추적 트리에 없다. package/binary 이름 `safehub_app`과
기존 `aircon` wire ID는 호환 식별자이며 옛 UI/에어컨 전용 화면이 다시 포함됐다는 뜻이 아니다.

## 필요한데 저장소에 포함되지 않은 자료

아래는 “장치에 없다”가 아니라 **현재 Git 추적 파일에 없거나 이 클라우드에서 미확보**라는 뜻이다.
임의 모델/펌웨어/기본 장치 설정을 만들어 대체하지 않았다.

| 항목 | 필요한 경로/역할 | 현재 판단 |
|---|---|---|
| Uno 실제 스케치 | `.ino`, 보드·핀·프로토콜·watchdog | Git 추적 .ino 0개. Python bridge만으로 펌웨어 재현 불가. 미수신 항목 |
| Palm/HandPose ONNX | `/data/safehub/models/{palm_detection_mediapipe_2023feb,handpose_estimation_mediapipe_2023feb}.onnx` | 사용 경로 보고 확보. 파일/현재 해시 미확보 |
| 추가 수어 참조 | `/data/safehub/active_targets_v4.bin` | live 시작에 필요. 경로 보고 확보, 현재 파일 미확보. 기본 15-class runtime_data와 별개 |
| 실제 Pi4 바이너리 및 시작 wrapper | `/data/safehub/vision_stream_sign_live_mqtt_rpi4`, `run_camera.sh`와 실행 설정 | 마지막 운영/후보 해시는 보고 확보. 현재 설치본·wrapper 원문·Git SHA 대응 미확인 |
| ARM64 도구/런타임 수집본 | portable build의 CROSS_ROOT/TARGET_ROOT/HEADERS_ROOT | 작성자 ARM64/ABI 보고는 있음. 이 환경 수집 사본은 미확보 |
| ATLAS SDK/audio plugin | `/opt/flutter-atlas-plugins/packages/flutter-plugin-atlas-audioplayers`, 팀 embedder/SDK | 외부 공급 의존. runner 및 record_atlas 소스는 Git에 있음 |
| PulseAudio helper | `/data/share/safehub-tools/parecord`, 오디오 서비스/권한 | PCM 녹음에 필요. 실제 장치 존재/동작 미확인 |
| STT 가중치/패키지 | `/opt/safehub-stt/korean-streaming-174m` | 다운로드·해시 검증 소스는 있음. 실제 모델/ARM64 설치 미실행 |
| fastText 실제 모델 | service의 `fire_screen_model.bin` | native runtime 검사와 fake 모델 규칙 검사는 있음. 실제 분류 모델 미확보/미검증 |
| CSI 기존 학습 모델 | 장치 data-dir의 모델 metadata/weights | 제품에서 선택·추론하려면 필요. 개인 모델/데이터를 Git에 넣지 않음 |
| 로컬 서비스 배치 | Mosquitto/Python 환경/receiver.env/USB·IP·shortcut 설정 | 소스/unit은 있으나 자동 설치 완료 아님. staging 도구는 Uno/fastText/hub 소스 부분만 다룸 |
| TTS/재난 API | 앱 설정의 서버 URL·필요 인증정보 | client 구현은 있음. TTS 서버 구현은 이 제품 트리에 없고 외부 서비스가 필요 |

### 버전·연결 주의점

- UI 기본 CSI 주소/일반 개발 bridge는 8765, Pi 제품 unit은 8769다. 기존 배포 안내대로
  Pi 앱 설정 `CSI_SERVICE_URL=http://127.0.0.1:8769`를 지정해야 한다. 개인 설정을 덮어쓰거나
  모든 PC 포트를 임의 변경하지 않았다.
- canonical ATLAS lock의 audioplayers 6.6.0과 host lock의 6.7.1은 다르다. host lock은
  Dart >=3.9/Flutter >=3.35.6을 요구하며 실제 검사는 Flutter 3.35.7/Dart 3.9.2다.
  호스트 성공을 팀 ATLAS SDK의 dependency resolution/링크 성공으로 대체하지 않는다.
- `.gitignore`는 모델·개인 설정·산출물을 제외한다. 원본이 허용되는 필요한 모델/펌웨어 자료는
  출처·해시·사용 권한을 확인해 별도 확보하고 제출 재현 목록에 포함해야 한다.

## 검사와 근거

- 전체 Flutter **254 pass / 0 fail / 1 skip**. 이전 272에서 미사용 녹음 서비스 전용
  18개를 제거한 결과다. 현행 자막/마이크 테스트는 유지. 이후 미사용 helper 제거는 관련
  재난/경보/CSI 검사 **21개 통과**로 추가 확인했다. 최종 원격 CI는 해당 head에서 별도 확인한다.
- Flutter 분석 **0 error / 0 warning / 102 info**, `--no-fatal-infos` exit 0.
- 기존 source/host 패키징 **6/6**, Windows 도구 **14/14**, 도구 검사 **5/5**
  (기존 socket 차단 1 + 새 source audit 4).
- 추적 Python 124개 AST parse 성공(새 도구 2개 추가 전). 수어/비전 C++ 계열 99개
  quoted include 확인에서 미해결은 명시적 외부 MediaPipe 헤더 5개뿐이었다.
- C6 provenance **9/9**, CSI upstream manifest **6/6** 해시 일치.
- 개인키/GitHub token/AWS key marker의 제한적 정적 검색에서 일치 0개. 완전한 비밀정보
  부재 보장은 아니며 개인 설정을 커밋하지 않았다.
- 이번에는 수어 C++/Uno/문맥/CSI runtime 제품 코드를 변경하지 않았다. 기존 통과 검사를
  전부 로컬 반복하지 않았고 최종 CI의 비장비 검사를 함께 확인한다.

로그와 복구 bundle은 `/workspace/.cloud-setup/final-source-audit-20261027/`에 보존한다.
실제 장치 시험/서비스 제어/메시지 발행/실행본 교체/펌웨어 플래시는 하지 않았다.
현재 장치 보고와 미해결 쓰러지다/점등 문제는
[관찰 기록](user-device-observation-20261027.md), 성능 실험은
[카메라 추가 검토](../sign/camera-offline-review-20261027.md)를 참고한다.
