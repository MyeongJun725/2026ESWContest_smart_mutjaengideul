# 카메라·수어 처리 추가 검토와 오프라인 실험 · 2026-10-27

검토 기준은 PR #11 `23b3df55aadbf408fae4ad278d2e18e5e49e1e0b`의 제품 소스다.
이번 변경은 진단 도구와 문서만 추가한다. 인식 임계값·통신·장치 실행본은 바꾸지 않았다.

## 학진이 변경의 포함 여부

PR 작성자와 커밋 작성자를 구별했다. GitHub에서 학진이 계정의 PR은 #1/#4로
조회되지만, 명준이 계정의 PR #9에도 학진이 후속 커밋이 들어 있다.

| 변경 | 확인 |
|---|---|
| #1의 C++ 분류기/JSONL 통합 | 기존 코드에 포함. Python/C++ parity는 정확도와 별개 |
| #9 `ef25a646ee8fd020e6bdc2fea18785b9c0580b4d` | 학진이의 느린 수어 구간 보존·불완전 양손 보류 후속 수정. #11 HEAD의 ancestor 확인 |
| #9 `ae887ac277bb0e3fc95ad4dc766f678b29bb9876` | 학진이의 ARM64 후보 빌드/정적 ABI 검증 기록. #11 HEAD의 ancestor 확인 |
| `1323530`/`b1af64f` | 캡처·추론 분리/미리보기 지연 최적화. 현재 코드에 유지되며 Git 작성자는 김민범 |

어느 변경을 사용자가 기억한 “학진이 카메라 최적화”로 지칭했는지는 확정하지 않는다.
PR #9의 ARM64/장치 수집 기록은 작성자 보고이며 이번 클라우드 작업자의 직접 장치 시험이 아니다.

## 구조·전처리·복잡도

현재 live 경로는 `photo_pipeline/vision_stream_sign_decoupled.cpp`다.

- 생산자/추론 사이에는 최신 프레임 한 개의 mailbox를 둔다. mailbox 교체/취득은 O(1)이며
  이미지 복사와 반전은 픽셀 수 P에 대해 O(P)다. 뒤처진 프레임을 무제한 큐에 쌓지 않는다.
  처리 중 프레임과 임시 이미지도 존재하므로 전체 메모리가 한 프레임이라는 뜻은 아니다.
- 미리보기는 최대 8 FPS(125ms 간격), 320×240 RGBA다. 프레임 payload는 307,200 bytes,
  최대 약 2.46 MB/s다(헤더/네트워크 오버헤드 제외). nonblocking 송신 중 pending 프레임이
  있으면 새 미리보기를 버린다. 실제 네트워크 속도·장치 표시 FPS는 측정하지 않았다.
- Palm 입력은 종횡비 유지 resize+padding으로 192×192 RGB float32 NHWC,
  HandPose는 crop/padding/rotation/resize로 224×224다. 좌표는 crop bias와 역회전으로 복원한다.
  live의 반전과 classifier bridge의 좌표 보정을 함께 봐야 한다. 사진/옛 host 도구를
  현재 live와 동일한 경로로 취급하지 않는다.
- Palm은 고정 2016 anchor를 decode한다. 후보 K개의 정렬은 O(K log K), greedy NMS는
  최악 O(K²)다. 모델 호출 횟수 제한이 NMS의 모든 비용까지 상수 시간으로 보장하지는 않는다.
- 공유 예산은 처리 프레임당 Palm 최대 1회, HandPose 최대 5회다. 정상 추적은 더 적은
  호출로 처리하고, ROI 재시도와 detector fallback도 같은 예산을 사용한다.
  추적 성공 시 정기 Palm scan은 capture 시간 기준 700ms지만 실패 시 더 자주 실행될 수 있다.
- ROI 이미지 면적 A의 색변환/회전은 O(A), tensor 생성은 고정 입력 크기에 선형이다.
  ONNX 추론의 실제 비용은 모델 연산량·스레드·CPU에 달려 있으며 big-O만으로 FPS를 계산할 수 없다.
- 분류기는 현재 RMSE 참조 비교를 사용한다. 대표 비용은 참조 수 R, 재표본화 길이 T,
  특징 차원 D에 대해 O(RTD), 거리 정렬 비용이 추가된다. DTW O(T²) 알고리즘으로 계산하면 안 된다.
  One-hand 기본 42×80×84는 282,240개 요소 비교, two-hand 기본 60×80×84는 403,200개다.
  C4/추가 ranking/rescue 경로는 별도 비용이며 이 수치를 전체 연산 수로 주장하지 않는다.

### 인식률·지연 측면에서 남는 문제

최신 프레임 방식은 대기열 지연을 줄이지만 빠른 손동작의 관측도 줄인다. live 구간 수집기는
최소 10/최대 90 **손 관측 프레임**으로 구성돼 있으나 classifier의 원본 특징 선택에는
최소 20프레임 조건이 있다. 10~19프레임 구간이 수집됐다고 분류 가능한 것은 아니다.
20개 유효 관측에는 5 FPS에서 약 4초, 1 FPS에서 약 20초가 필요하다
(샘플 수/처리율의 근사이며 실제 첫/끝 시각과 다름). 양손 동시 관측 부족은 별도 제약이다.

`ef25a64`는 낮은 FPS에서 한 번의 누락으로 구간이 조기에 잘리는 것을 줄인다.
기본 350ms/양손 복구 650ms와 cadence allowance 중 큰 값을 사용하며 allowance는 최대
2250ms다. 정상 입력 보존에는 유리하지만 동작 종료/분리 지연과의 균형은 장치에서 확인해야 한다.

또한 `capture_time`은 stdin read·반전·미리보기 처리·clone 이후 찍는다. 기존 frame-age
통계는 실제 센서 촬영부터 UI 표시까지의 지연이나 상위 카메라 pipe 대기 시간을 포함하지 않는다.

## 실제 수행한 실험

도구: `tools/sign_regressions/camera_offline_probe.cpp`. 카메라·ONNX·MQTT·직렬 포트를
열지 않고 기존 runtime_data와 87프레임 landmark fixture로 production classifier를 호출한다.
환경은 Linux x86_64 AMD EPYC 9V74, GCC 14.2.0, Release O3/ffp-contract=off다.
세션 한도는 live와 같은 10/90/5를 명시한다. 각 분류 사례는 warmup 3회/측정 30회,
모델 로딩·파일 읽기·로그 출력은 측정 밖이다. p95는 정렬한 30개 중 29번째 값이다.

| 실험 | 결과/한계 |
|---|---|
| 원본 양손 87프레임 fixture | ID 12(온도), `TWOHAND_BASE_LOCAL`. 기존 fixture 예상과 일치 |
| 완전히 빈 recording | invalid, ID -1. 정상적으로 분류하지 않음 |
| 원본의 0/43/86번째 손 좌표를 한 손씩 90회 반복한 6사례 | 4사례는 ID 11(소등), 2사례는 NO-SIGN. 정지 landmark 입력의 수어 출력 가능성을 확인 |
| 손 검출이 없는 합성 30초/30 FPS | 완료 구간 0개 |
| 같은 손 검출을 유지한 합성 30초/30 FPS | 90관측에서 완료 구간 1개, 이후 release 대기. 매 프레임 반복 분류하지 않음 |

정지 좌표는 **수어 fixture의 자세를 반복한 합성 입력**이다. 실제 사용자 무동작의 정답 데이터가
아니므로 4/6을 실제 무동작 오인식률로 해석하지 않는다. 소등 결과는 사용자가 보고한
점등 현상의 재현도 아니다. 정상 수어 중 정적인 자세가 의미를 가질 수 있으므로 움직임
임계값으로 일괄 거절하거나 해당 클래스를 삭제하지 않았다.

분류기만의 중앙 처리 시간은 이번 실행에서 대략 0.2~0.6ms 규모였다. 이 결과는
카메라 전처리·Palm/HandPose·Pi 성능을 포함하지 않으며 전체 FPS로 환산하지 않는다.
공유 클라우드 CPU의 짧은 실험이고 단일 양손 fixture이므로 일반 성능 보장도 아니다.
원본 측정 JSONL/빌드 로그는 `/workspace/.cloud-setup/camera-review-20261027/`에 보존했다.

관련 기존 CTest 6개(15-class parity, live timing, hand coverage, observation,
Palm retry, ROI retry policy)를 다시 실행해 6/6 통과했다. 전체 이전 검사를 반복하지 않았다.
OpenCV 개발 헤더/라이브러리와 실제 ONNX 모델은 이 환경에서 미확보이므로
crop/NMS/ROI 실제 OpenCV 검사 및 실제 모델 성능 실험은 **이번에 미실행**이다.
기존 #9의 작성자 검사 기록과 혼동하지 않는다.

## 재현

저장소 루트에서 별도 빌드 폴더를 사용한다. 기존 CMake 3.20+/C++17 환경이 필요하다.

```bash
cmake -S tools/sign_regressions -B /tmp/safehub-camera-probe -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/safehub-camera-probe --target camera_offline_probe -j 2
/tmp/safehub-camera-probe/camera_offline_probe "$PWD"
```

도구는 기본 build/CTest에 추가되지 않는 opt-in 진단 target이다. 성능 수치를 강제로
통과/실패 기준으로 사용하지 않는다. runtime_data는 실제 ONNX 검출 모델과 별개다.

## 실제 장치에서 이어서 볼 항목

손 없음/손 정지/실제 점등·소등을 구분한 입력, 실패한 양손 단어별 반복 영상 및 결과,
Palm/Hand 호출 수·processing_ms·관측 FPS·paired 수·종료 사유·최종 stage를 같은 구간에서
확보해야 한다. 모델·바이너리·원본 SHA와 MQTT 최초 출력/재전달도 구분한다.
기준 실행본과 후보를 동일 입력으로 비교한 뒤 정확도/지연 개선 여부를 판단한다.
[사용자 관찰 기록](../integration/user-device-observation-20261027.md)을 함께 참고한다.
