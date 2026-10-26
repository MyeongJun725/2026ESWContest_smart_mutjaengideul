# PR #9 후속 보완 검증 — 2026-10-26

아래 ARM64 보류 기록 이후 사용자가 빌드를 재개 요청했다.
최신 빌드 및 정적 ABI 검증은 [portable 후보 빌드 보고서](word1229-portable-build.md)를 참조한다.

## 기준과 작업 범위

- PR: https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/pull/9 (Draft).
- 원격: https://github.com/MyeongJun725/2026ESWContest_smart_mutjaengideul.git
- 동일 작업 브랜치: `fix/rpi4-overlap-word1229`, 추적 원격 `pr9`.
- 확인 및 fetch한 최신 커밋: `f2a186a652445f9d70d826c4f7436876a2f4dc7e`.
- 별도 worktree: `C:\Users\22212\.codex\worktrees\rpi4-pr9\2026ESWContest_smart_mutjaengideul`.
- 기존 폴더의 Pi5 `main.py` 변경 및 GRU 코드·데이터·모델은 수정하지 않았다.
- 정답 대상: 쓰러지다 WORD1229, 내부 ID 15. 합성 회귀 검사이며 해당 수어의 실영상 정확도 검증은 아니다.

최신 커밋에는 두 조건의 검사가 없었다. 먼저 검사만 추가하여 두 실패를 재현한 다음
관련 로직만 수정했다. 기존 손 병합·ROI·추론 예산·좌표 보정·MQTT·추가 참조 구현은 유지했다.

## 1. 0.8~1.5초 불규칙 관측 간격

800/1500/1100ms 간격을 반복하며 손이 계속 검출되는 30개 관측은 기존 코드도 유지했다.
그러나 13번째 관측만 빈 프레임이면 기존 350/650ms 제한 때문에 다음 관측에서
12개와 17개 손 프레임으로 분리되어 둘 다 최소 20개 기준에 미달했다.

최근 8개 관측 간격의 최댓값에 1.5를 곱한 값을 기본 종료 대기 350ms,
최근 양손 손실 시 650ms와 비교하여 더 큰 값을 사용한다. 간격은 1500ms로 제한하므로
종료 대기 임계값은 최대 2250ms다. 빈 관측이 시작된 후에는 간격 추정을 동결하여
긴 미검출이 자기 자신의 종료 시간을 계속 늘리지 못하게 했다.

- 느린 주기에서 연속 검출 및 단일 빈 관측: 하나의 30프레임 구간 유지.
- 1500ms 주기에서 지속 미검출: 최초 빈 관측 후 3000ms의 실제 다음 관측에서 종료.
  2250ms는 임계값이며 타이머가 별도로 실행되는 구조가 아니므로 실제 종료는 다음 관측 시점이다.
- 기존 5/15/30fps 종료, 빠른 주기의 700ms 공백 분리, 역행 시각 거절도 통과.
- 기존 양손 복구 대기 중 빈 프레임은 실제 빈 관측으로 남는다. 좌표 보간이나 복제 없음.

느린 주기의 단일 미검출을 허용하면서 서로 다른 동작이 합쳐질 가능성은 현장에서 측정해야 한다.
이 변경은 처리 FPS 향상이나 실제 수어 정확도 향상을 입증하지 않는다.

## 2. 양손 8 → 한 손 22 → 양손 1

기존 `trailing_single`은 마지막 양손 프레임에서 0이 되어 보류가 풀렸다.
이제 접촉 관측 3개 및 연속 양손 관측 3개를 확보한 이후의 가장 긴 한 손 손실 구간을
별도로 기억한다. 마지막 한 쌍만으로 그 이력을 지우지 않는다.
기존 paired 수·비율 조건과 5개 연속 빈 관측의 초기화는 유지한다.

- 8/22/1: 기본 분류와 active-target 경로 모두 `INCOMPLETE_TWO_HAND_TRACK` 유지.
- 추가 양손 11개로 paired 총 20개 확보: 이 보류 조건 해제.
- 한 손 22개 이후 접촉 양손 8개: 접촉 이전 손실만으로 보류하지 않음.
- 기존 먼 보조 손, paired 1~2개, 충분한 양손 기록, 순수 한 손, 빈 구간으로 분리된 동작 대조 검사 통과.

## 실행 결과

Windows x64, MSVC 19.43, Release에서 assertion을 활성화한 CTest:
**19/19 통과**, Python 진단 도구 **3/3 통과**.
기존 15개 클래스 parity, runtime route, TEMP, 에어컨, 좌표 브리지, 비동기 큐 검사 포함.
검사만 추가한 최초 실행에서는 요청한 두 테스트가 모두 실패했고, 코드 수정 후 전체 통과했다.

```powershell
$cmakeBin = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin'
& "$cmakeBin\cmake.exe" -S tools/sign_regressions -B build/sign-regressions
& "$cmakeBin\cmake.exe" --build build/sign-regressions --config Release
& "$cmakeBin\ctest.exe" --test-dir build/sign-regressions -C Release --output-on-failure
& C:\Users\22212\anaconda3\python.exe -m unittest discover -s SW/rpi4_vision_atlas/tests -p test_sign_capture_diagnostics.py -v
```

최초 PR의 21개 결과와 구별한다. 이번 환경에서는 선택적 OpenCV crop/NMS 및 ROI runner
2개 검사와 전체 live translation unit 객체 컴파일은 구성하지 않았다.
기존 `word1229-validation.json`은 친구의 이전 검증 기록이며 이번 실행 결과로 덮어쓰지 않았다.

## ARM64 빌드 재개에 필요한 파일·도구

사용자 요청으로 SDK 경로 확인과 후보 빌드를 보류했다. **ARM64 ELF는 생성하지 않았다.**
현재 WSL Ubuntu의 `/opt`와 사용자 홈에서 ATLAS SDK를 찾지 못했으며 발견된 ORT 1.29는
x64 라이브러리여서 Pi4 후보에 사용할 수 없다.

1. 기존 Pi4 ATLAS 이미지와 호환되는 Yocto/ATLAS SDK 및 `environment-setup-*` 파일.
2. 해당 SDK의 AArch64 C++17 컴파일러·링커, `CXX`, `SDKTARGETSYSROOT` 설정.
3. 타깃 sysroot와 libc/libstdc++/동적 로더. ARM64 binutils `readelf`, `objdump` 또는 SDK 대응 도구.
4. OpenCV 4.9 헤더와 ARM64 `libopencv_core.so.409`, `libopencv_imgproc.so.409` 및 전이 의존 라이브러리.
5. ONNX Runtime 헤더 및 호환되는 ARM64 `libonnxruntime.so.1`.
6. Paho MQTT C 헤더 `include/MQTTClient.h`와 ARM64 `lib/libpaho-mqtt3c.so`.
7. `VISION_LIB_DIR`, `PAHO_SDK_DIR`, Bash, Git, SHA256 도구 및 빌드 소스 checkout.
   Windows worktree의 `.git`은 Windows 절대경로를 사용하므로 Linux 빌드 시 Git 경로 호환도 확인해야 한다.

환경 준비 후 기존 `SW/rpi4_vision_atlas/tools/build_word1229_candidate.sh`를 실행한다.
새 `build/word1229-candidate/vision_word1229_candidate`만 만드는 스크립트이며 실제 SDK 실행은 미검증이다.
ELF의 AArch64 형식, interpreter, NEEDED 및 GLIBC/GLIBCXX 요구 버전과 타깃 라이브러리 대응을
확인하고 SHA256·기준 커밋·변경 패치를 함께 보관해야 적용 후보라고 판단할 수 있다.
빌드 성공만으로 카메라/수어 실동작이 검증되는 것은 아니다.

## Pi4 보존 및 이후 백업·복원

이번 작업에서는 Pi4 연결·서비스 중지·실행본/모델/참조 교체를 하지 않았다.
현재 장치 해시를 새로 측정한 것도 아니다. 이전 PR에 기록된 해시는 과거 검증 값이다.
향후 적용 전 [기존 백업·복원 절차](word1229-overlap-review.md#빌드적용복원-절차)에 따라
현재 ELF와 `/proc/PID/exe`, 참조, runtime_data, 실행 스크립트, 서비스/drop-in 및 로그를
별도 날짜 디렉터리에 보관하고 SHA256을 기록한다. 후보는 별도 경로를 사용한다.
복원 시 후보를 중지하고 백업한 실행 설정과 원본 ELF/참조를 사용하여 서비스를 재시작한 뒤
실행 중인 ELF 해시를 백업 당시 값과 대조한다. 적용·복원 명령은 실행하지 않았다.
