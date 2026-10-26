# WORD1229 쓰러지다: 소스 수정안과 검증 상태

2026-10-26. **현재 Pi4에 설치하는 배포본이 아니다.** 원본 영상/문제 좌표가 제공되지 않아 그 기록을 재생한 검증은 하지 않았다. 실제 양손 검출 회복률·수어 정확도·지연 개선은 미검증이다.

## 소스 대응 확인

- GitHub 기준: `minbeom77/2026ESWContest_smart_mutjaengideul`, `develop`, `3ecfa82eff1d2c96118d5015697ac34455ec95a3`.
- 작업 브랜치: `fix/rpi4-overlap-word1229`.
- upstream 원격 브랜치 22개를 조회했다. 해당 실행 경로가 있는 16개 브랜치의 파일과 전체 C++ 소스에서 배포 전용 기능 이름을 검색했다. 현재 배포 기능 전체와 대응하는 GitHub 소스는 찾지 못했다.
- `fix/rpi4-input-bridge-20261009-080540`의 `993a1036dd45feba5faf77b9861d520c609c20c6`에는 이전 입력 보정·연결 유지 수정이 있지만, 현재 장치의 복구·추가 참조·비동기 큐 전체를 포함하는 소스는 아니다.
- Pi4 실행 파일과 `/proc/180182/exe` SHA256을 직접 확인했다: `5b2f19129411cfe0a162b5f63f3410b36f9240e3d2faf3981860071735f55499`.
- 장치의 `/data/safehub/sign_async_publish_rpi4_v1/vision_sign_tracking_fix_rpi4`도 같은 해시다. 이 묶음의 `source/` 48개 파일은 포함된 SHA256 명세와 일치했다. 현재 수정안에는 이 소스의 GitHub 대비 차이도 명시적으로 복구했다.
- 이것은 **같은 바이너리를 포함한 소스 묶음을 확보한 근거**다. 그 소스로 깨끗하게 다시 빌드하여 같은 ELF가 나오는 재현성 검증은 아니다. 과거 다른 PC의 빌드 경로가 지금도 같다고 단정하지 않는다.
- 원래 참조 `/data/safehub/active_targets_v4.bin` 해시: `f1c3cec6b057a053733dc45690317724745cc47258a2f34753e4659ad669d7d7`. 모델·참조·카메라 실행 스크립트·서비스·원본 로그를 변경하지 않았다.

세부 파일 해시와 원격 브랜치 목록은 [word1229-source-audit.json](word1229-source-audit.json)에 있다.

| 기능 | GitHub develop | 확인한 장치 묶음 / 수정안 |
|---|---|---|
| 단어·추가 참조 | 기존 15개, 쓰러지다 추가 경로 없음 | 16번째 ID 15와 `active_targets.cpp` 복구, 기존 참조 유지 |
| 입력 좌표 보정 | live 경로에서 현재 helper와 대응하지 않음 | `restoreClassifierCoordinates()`를 분류 입력에 한 번만 적용 |
| 두 번째 손 복구 | 없음 | 기존 `LostSecondHandRecovery`를 시간 기준으로 수정 |
| 추적 ROI 재시도 | 없음 | 기존 square crop 재시도 유지, 같은 공유 예산 사용 |
| MQTT | 영상 루프에서 연결·전송 경로 호출 | 기존 비동기 큐·연결 유지 코드 복구, 주소·포트·토픽·payload 변경 없음 |

## 확인한 결함과 수정

1. **검출 결과 덮어쓰기:** 추적에서 한 손을 찾았어도 fallback의 `hands = run_hands(...)`가 그 손을 없앨 수 있었다. 같은 프레임의 성공한 손은 유지하고 새 검출만 병합한다. 이전 프레임 좌표는 넣지 않는다.
2. **복구 시간·추론량:** 기존 복구는 처리 프레임 3개에 소진되고, 정기 검출은 10개 처리 프레임마다였다. 복구를 1200ms 안에서 최대 4회, 최소 200ms 간격으로 변경했다. 정기 스캔은 캡처 시각 기준 700ms다. 추적·크롭 재시도·fallback을 합쳐 손 추론 최대 5회, palm 추론 최대 1회/처리 프레임이다. 이 값들이 실카메라 최적값인지는 미검증이다.
3. **동일 손 중복:** handedness만으로 두 손이라고 인정하지 않는다. 손목 거리와 21개 관절의 평균 거리를 손바닥 크기로 정규화하여 동일 손을 제거한다. 가까운 손목과 서로 다른 손가락 모양을 가진 두 손은 별도 대조 검사에 포함했다. 실제 겹친 손의 모든 중복을 해결했다고 주장하지 않는다.
4. **좌표 복원:** 패딩이 홀수 픽셀일 때 잘린 사각형의 중심을 사용하는 근사식은 실제 패딩 중심과 반 픽셀 차이가 날 수 있었다. 모델 좌표 → 패딩 포함 crop → inverse affine → 원본 좌표로 정확히 역변환한다. 이것이 사용자 영상의 검출 실패 주원인이라는 근거는 없다.
5. **잘못된 crop 예외:** 빈 영역/비정상 경계의 예외가 전체 추론으로 전파될 수 있었다. 그 후보만 거절하고 같은 프레임의 다른 성공 검출은 유지한다. 모델 로딩/추론 자체의 오류까지 무조건 숨기지는 않는다.
6. **구간 종료:** 실제 live 입력은 프레임 수 대신 캡처 시각을 사용한다. 기본 미검출 대기는 350ms, 최근 양손 손실 복구 중에만 최대 650ms다. 그보다 긴 공백 뒤 손은 새 동작으로 분리한다. 좌표 fixture용 옛 overload는 유지한다. 관측 프레임 수/실제 빈 프레임은 그대로 기록하며 보간으로 검출 수를 늘리지 않는다.
7. **불완전 입력의 한 손 확정:** 접촉에 가까운 양손이 3프레임 이상 연속 관측되고, paired 데이터 20개 미만·paired 비율 0.35 미만·한 손 tail 8개 이상인 경우 `INCOMPLETE_TWO_HAND_TRACK`로 보류한다. 잠깐 보인 먼 보조 손, 1~2개 paired 관측, 충분한 paired 기록, 순수 한 손 입력은 이 조건으로 막지 않는다. `active_targets.cpp`도 `KEEP_ONEHAND`보다 먼저 이 보류 결과를 존중한다.
8. **검사 도구:** GitHub에 기존 현장 검사 스크립트가 없어 새 읽기 전용 도구를 추가했다. 실행 중인 PID의 `/proc/.../fd/2`로 실제 stderr를 찾고, `processing_ms`를 float로 비교하며, 로그 교체/잘림 및 프로세스 변경은 검사 실패로 처리한다. 정답은 `--expected`로 명시하며 파일명 rescue를 정답으로 추측하지 않는다.

판단 보류 규칙은 인식률 향상과 별개다. 짧은 양손 접촉을 포함하는 정상 한 손 동작까지 보류할 가능성이 있으므로 실데이터에서 오차단을 따로 측정해야 한다. 기존 긴 paired 기록·TEMP rescue를 막던 초기 규칙은 회귀 검사에서 발견하여 범위를 제한했다. 임계 프레임 수를 낮추거나 불완전 기록을 참조에 추가하지 않았다.

## NMS·크롭에 관해 아직 가설인 부분

- NMS는 IoU 0.3, 손 confidence는 0.8을 유지했다. synthetic palm 출력에서 서로 다른 keypoint 후보도 상자가 겹치면 억제될 수 있음을 확인했지만, 실제 실패 프레임에서 그 일이 일어났다는 증거는 없다. NMS는 끄지 않았다.
- frame JSONL에 캡처 단조 시각, 추론 횟수, 후보 점수/크롭/회전각, crop 밖 palm 점 수, bounded NMS 억제 후보·유지 후보의 anchor/score/IoU/영역을 추가했다. 실제 겹침과 검출 실패의 동기화에는 별도 원본 영상이 필요하다.
- crop 확대가 다른 손으로 몰리는지, handedness가 바뀌는지, 낮은 모델 점수의 원인이 가림인지 모델의 일반화 한계인지는 아직 확인하지 못했다.

## 검증 구분

- Windows MSVC 호스트: C++ 회귀 21개. 기존 15개 클래스 parity, 기존 런타임 4개 route, 한 손 입력, 온도/TEMP, 에어컨/추위, feature·좌표 브리지, 비동기 큐, 시간 경계, 공유 추론 예산, 중복 병합 검사 포함.
- OpenCV 4.9 실제 전처리 함수 실행 + **합성 모델 출력**: crop/회전/경계·0.8 confidence·NMS 진단·ROI runner 검사. ONNX 모델이 사람의 손을 재검출한 성과가 아니다.
- Python 진단 도구 3개: 실제 stderr 경로 사용, 99/474/598/814/1415 숫자 최댓값, 로그 잘림 감지.
- 전체 live C++ translation unit을 OpenCV 4.9/ONNX Runtime 1.21/Paho 1.3.13 헤더로 MSVC 객체 컴파일했다. **ATLAS ARM64 최종 링크/실행 검증은 아니다.**
- Pi4에서는 기존 프로세스를 읽기만 했다. 카메라·MQTT·Pi5 UI 연결은 살아 있었다. 최근 로그에서 관측 수 10~15로 기존 20개 분류 기준에 부족해 버린 사례가 있었다. 표준화된 정답 동작 시험이 아니므로 정확도·재현 결과로 집계하지 않는다.
- 원본 문제 영상·32/46프레임 좌표·쓰러지다 실제 재현·낙상 감지·보호자/119 연동·발열/성능 개선은 이 결과로 검증되지 않는다.

## 빌드·적용·복원 절차

현재는 1~2단계까지만 수행할 후보이며, 호스트 검사 통과만으로 3단계에 들어가지 않는다.

1. **소스 비교:** 위 커밋의 GitHub 소스, 장치 소스 묶음, 이 브랜치 diff를 검토한다. 장치에서 쓰는 좌표 보정·ROI 복구·active target·비동기 MQTT가 모두 포함되는지 확인한다. SHA manifest와 현재 모델 해시를 보관한다.
2. **별도 빌드:** 기존 ATLAS SDK 환경을 source한 뒤 `SDKTARGETSYSROOT`, `CXX`, `VISION_LIB_DIR`, `PAHO_SDK_DIR`를 설정하고 `bash SW/rpi4_vision_atlas/tools/build_word1229_candidate.sh`를 실행한다. 이 스크립트는 새 `build/word1229-candidate/vision_word1229_candidate`만 만든다. SSH·서비스 중지·모델 변경·설치는 하지 않는다. 이 ARM64 빌드 스크립트 자체의 실제 SDK 실행은 아직 미검증이다.
3. **향후 명시적 적용 전 백업:** Pi4 현재 ELF와 `/proc/PID/exe` 해시를 다시 확인한다. 별도 `/data/safehub/backups/word1229-날짜시간/`에 원래 ELF, `active_targets_v4.bin`, runtime_data, `run_camera.sh`, `safehub-bootstrap.service`와 drop-in을 보관하고 SHA256 목록을 만든다. 카메라 서비스를 중지하기로 결정한 후 기존 `current.jsonl`·실제 stderr도 복사한다. 기존 `run_camera.sh`가 시작 시 JSONL을 지울 수 있기 때문이다. MQTT 설정은 변경하지 않는다.
4. **검증용 실행:** 모델/보정·ARM ABI·라이브러리 링크를 확인한 후에만 별도 candidate 경로를 사용하도록 실행 방법을 명시적으로 전환한다. 원래 경로에 무조건 복사하지 않는다. 기존 카메라를 중지한 뒤 단 하나의 카메라 프로세스만 실행한다. 정답이 확인된 영상의 양손 검출 비율/누락 연속 시간/숫자 지연, 정상 한 손·구조·에어컨, 오출력 보류를 구분해서 비교한다. 정확도가 확인되기 전 배포본으로 부르지 않는다.
5. **복원:** 적용 시 바꿨던 서비스 설정만 백업 설정으로 되돌리고, candidate 프로세스 중지 후 원래 ELF·원래 참조를 사용해 기존 `safehub-bootstrap.service`를 시작한다. 백업 ELF와 실행 중 `/proc/PID/exe` 해시가 원래 `5b2f...55499`인지 확인한다. 원래 ELF를 덮어쓰지 않는 방식이면 바이너리 복사는 필요 없다. 이 작업 중에는 적용/복원을 실행하지 않았다.

호스트 재검사:

```sh
cmake -S tools/sign_regressions -B build/sign-regressions
cmake --build build/sign-regressions --config Release
ctest --test-dir build/sign-regressions -C Release --output-on-failure
python -m unittest discover -s SW/rpi4_vision_atlas/tests -p test_sign_capture_diagnostics.py -v
```

OpenCV를 사용하는 2개 검사는 CMake의 `OPENCV_SOURCE_ROOT`, `OPENCV_BUILD_ROOT`, `ORT_HEADERS`가 필요하다. 전체 live 객체 컴파일에는 `PAHO_HEADERS`도 필요하다. 경로를 지정하지 않으면 순수 C++ 검사 19개만 구성된다. 네트워크 큐 검사는 scripted sender를 사용하며 실제 브로커로 시험 메시지를 발행하지 않는다.
