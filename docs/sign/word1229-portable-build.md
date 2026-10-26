# WORD1229 ARM64 portable 후보 빌드 — 2026-10-26

**ARM64 전체 빌드/링크 및 정적 타깃 ABI 검사 통과. 장치 실행·배포는 하지 않았다.**
후보 SHA256: `5c14f1fc0d7741417b46299b8ad010054ee509167eeda16c7a9b7a48e34d775c`.
검사 상세: [word1229-portable-abi.json](word1229-portable-abi.json).

## 기준과 보존 범위

두 보완 수정 및 호스트 회귀 결과는 PR #9의 기존 브랜치
`fix/rpi4-overlap-word1229`에 `ef25a646ee8fd020e6bdc2fea18785b9c0580b4d`로 푸시했다.
푸시 직전 확인한 원격 기준은 `f2a186a`였고 추가 커밋이 없어 fast-forward로 반영했다.
원래 작업 폴더의 Pi5 변경 및 GRU 자산은 수정하지 않았다.

장치에서 `/data/safehub/sign_async_publish_rpi4_v1/build_portable.sh`를 읽었다.
기존 방식은 ATLAS SDK 전용 경로가 아닌 GCC 13 교차 sysroot, 별도 헤더,
장치 라이브러리 묶음의 조합이었다. `apply.sh`, `rollback.sh`, 서비스 제어 또는
카메라 테스트 스크립트는 실행하지 않았다.

## 사용한 환경과 출처

| 항목 | 고정한 버전 / 출처 |
|---|---|
| Pi4 | ATLAS 26.06.0-246.scarthgap.s6, AArch64 |
| 교차 C++ 컴파일러 | Ubuntu noble GCC 13.2.0-23ubuntu4cross1 |
| 개발 sysroot | noble libc6-dev-arm64-cross 2.39-0ubuntu8cross1 |
| 교차 binutils | noble 2.42-4ubuntu2, 호스트 libsframe1 동일 버전 |
| 실제 타깃 glibc | Pi4 GNU libc 2.39 |
| OpenCV 헤더 | 공식 opencv/opencv 태그 4.9.0 |
| ORT 헤더 | 공식 microsoft/onnxruntime 태그 v1.24.4, API 24 |
| Paho 헤더 | 공식 eclipse-paho/paho.mqtt.c 태그 v1.3.13 |
| 링크 라이브러리 | 실제 Pi4 `/data/safehub/lib` 및 `/usr/lib`에서 수집한 파일 |

WSL 기본 저장소의 최신 개발 sysroot 2.43은 사용하지 않았다. Ubuntu noble
고정 배포판 패키지를 다운로드해 `Packages.xz`의 SHA256과 대조하고 별도 디렉터리에 풀었다.
시스템 패키지 설치·업그레이드는 하지 않았다. 패키지 의존성으로 추출된 Ubuntu 런타임을
Pi4에 설치하거나 배포하지 않았다. 최종 동적 링크는 장치의 libc/libm/libstdc++/libgcc_s와
ONNX Runtime/OpenCV/Paho를 사용하도록 우선 경로와 로컬 linker alias를 지정한다.

OpenCV 소비자 헤더에 필요한 `opencv_modules.hpp`에는 실제 링크하는
`HAVE_OPENCV_CORE`, `HAVE_OPENCV_IMGPROC`만 선언했다. OpenCV 구현이나 CPU 설정은 재빌드하지 않았다.
장치 로더의 `__stack_chk_guard@GLIBC_2.17`을 사용하기 위해
`-l:ld-linux-aarch64.so.1`을 명시했다. 스택 보호 옵션을 비활성화하지 않았다.

## 로컬 산출물과 재현

worktree의 `build/portable-pr9/`에는 다음을 보관한다. 이 폴더는 Git 추적 대상이 아니다.

- `device-build_portable.sh`: 장치의 원래 빌드 스크립트.
- `vision-build-runtime.tar.gz`, `target/`: 장치에 보관된 런타임 묶음과 수집 라이브러리.
  묶음 안의 과거 ELF는 현재 실행본으로 간주하지 않는다. 실제 실행 프로세스 해시는 별도 확인한다.
- `device-SHA256SUMS`: 현재 장치에서 읽은 13개 런타임/로더 파일의 해시.
- `device-process-maps.txt`: 기존 수어 프로세스의 실제 로딩 경로.
- `toolchain-packages.json`, `host-linker-dependency.json`, `.deb`: 버전·공식 다운로드 경로·검증 해시.
- `header-hashes.json`, `source-hashes.json`: 헤더 198개 및 프로젝트 소스 57개 해시.
- `linux-cache-path.txt`: 고정 교차 도구와 헤더를 풀어 둔 WSL 전용 캐시 경로.
- `candidate/vision_word1229_candidate`, `link.map`, `SHA256SUMS`, `elf-report.txt`, `abi-validation.json`.

WSL Bash에서 기존 로컬 수집 폴더를 기준으로 실행한다:

```bash
cd build/portable-pr9
cache=$(cat linux-cache-path.txt)
export CROSS_ROOT="$cache/cross" HEADERS_ROOT="$cache/headers"
export TARGET_ROOT="$PWD/target" OUT_DIR="$PWD/candidate"
bash ../../SW/rpi4_vision_atlas/tools/build_word1229_portable.sh
python3 ../../SW/rpi4_vision_atlas/tools/verify_candidate_abi.py \
  --candidate candidate/vision_word1229_candidate --target-root target \
  --device-hashes device-SHA256SUMS --output candidate/abi-validation.json
```

다른 환경에서는 위 버전과 출처의 도구/헤더 및 실제 장치 파일을 준비한 후 경로를 설정한다.
`target/usr/lib`의 로컬 alias는 `libstdc++.so → libstdc++.so.6 → libstdc++.so.6.0.32`,
`libgcc_s.so → libgcc_s.so.1`, `libc.so → libc.so.6`, `libm.so → libm.so.6`,
`libpaho-mqtt3c.so.1 → libpaho-mqtt3c.so.1.3.13`, `libz.so.1 → libz.so.1.3.1`이다.
이 링크들은 수집 사본에만 생성하며 장치 파일은 변경하지 않는다.

## 검증 해석

- 후보 및 의존 라이브러리 10개: AArch64, ELF64, little-endian 모두 확인.
- interpreter: `/lib/ld-linux-aarch64.so.1`.
- 후보의 필수 GLOBAL import 182개 및 의존성 전체의 필수 심볼: 누락 0개.
- 장치에서 읽은 라이브러리/로더 13개 해시: 모두 일치.
- linker map에서 동적 링크가 수집한 실제 Pi4 라이브러리로 향하는 것을 확인.
- `GNU UNIQUE` 방식의 C++ locale 심볼 두 개도 제공 심볼로 검사한다.
- 검사기 대조 시험: 잘못된 SHA256 및 검증 목록에서 제외한 libz 의존성을 각각 거절함을 확인.

정적 검사기는 수집 파일 SHA256, 후보 및 모든 의존 ELF의 AArch64/ELF64/little-endian 형식,
동적 로더 경로, 전체 NEEDED 의존성, 버전이 붙은 필수 GLOBAL import를 대조한다.
해시로 검증되지 않은 파일은 심볼 제공자로 인정하지 않으며 선택적 WEAK import는 필수 실패로 세지 않는다.
이 검사는 타깃 ELF/심볼 호환성 검사다. 실제 카메라·모델 초기화·MQTT·현장 수어 정확도,
OpenCV C++ 객체 레이아웃의 모든 차이 또는 OS 동작까지 입증하지 않는다.
후보를 장치에서 실행하거나 배포하지 않는다.

## 장치 보존 확인

수집 전후 `safehub-bootstrap.service`는 active, MainPID 253772,
시작 시각 2026-10-26 20:09:51 KST로 유지됐다. 수어 프로세스 PID 253777도 유지됐다.
실제 `/proc/253777/exe`와 설치 경로 `/data/safehub/vision_stream_sign_live_mqtt_rpi4`의
SHA256은 모두 `5b2f19129411cfe0a162b5f63f3410b36f9240e3d2faf3981860071735f55499`다.
`active_targets_v4.bin`은 `f1c3cec6b057a053733dc45690317724745cc47258a2f34753e4659ad669d7d7`로 유지됐다.
서비스 재시작, 실행본 교체, 참조 변경 및 테스트 MQTT 발행을 하지 않았다.
