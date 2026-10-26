# 권장안 적용: 현재 제품 UI 통합본

사용자가 2026-10-27에 백업과 복원 가능성을 조건으로 여섯 권장안을 모두 승인했다.
기존 Draft PR #11과 `integration/scenario-stability-20261026`에서 이어 작업했다.
이 문서가 이전의 “제품 범위 결정 대기” 기록을 대체한다. 실제 장치 배포 승인은 아니다.

## 먼저 확보한 복구 지점

- 정리 전 원격 PR #11/로컬 SHA: `d6be7c7f74a4e715cff73979f2a5d16c1cb31d0c`.
- [GitHub 보존 브랜치](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/tree/backup/pr11-before-product-cleanup-20261027)
  `backup/pr11-before-product-cleanup-20261027`을 같은 SHA로 push하고 `ls-remote`로 확인했다.
- 로컬 `/workspace/.cloud-setup/product-cleanup-preservation-20261027/`에
  `before-product-cleanup.bundle`, `github-source-before-cleanup.tar.gz`, 파일 SHA256 manifest를
  두었다. bundle은 전체 Git 이력 검증을 통과했다. 소스 tar.gz를 별도 임시 폴더에 실제로
  풀어 **847개 파일이 백업 Git blob과 모두 일치**함을 확인했다. 원래 develop 체크아웃도 그대로다.
- 변경은 기능별 새 커밋으로 저장했다. reset/clean/force-push/기존 브랜치 삭제는 하지 않았다.

복원은 작업 파일을 먼저 보존한 뒤 **백업에서 새 검토 브랜치를 만들어** 비교할 수 있다.
현재 통합 브랜치/main/develop을 강제로 되돌릴 필요가 없다.

```sh
git fetch origin backup/pr11-before-product-cleanup-20261027
# 현재 변경을 보존하고 깨끗한 작업 공간에서만 실행
git switch -c review/before-product-cleanup origin/backup/pr11-before-product-cleanup-20261027
```

파일만 확인할 경우 백업의 `git archive` 또는 소스 tar.gz를 저장소 밖의 새 빈 폴더에
풀면 된다. 기존 작업 폴더나 실제 설치본 위에 풀지 않는다. 이 복원 경로는 소스/Git 기준이며
미확인인 장치 IPK·설정 보관본을 새로 확보했다는 뜻은 아니다.

## 여섯 승인 항목의 결과

| 항목 | 최종 처리 |
|---|---|
| 옛 UI | `SW/safehub_app` 삭제. 현재 UI는 `SW/safehub_scenario` 하나이며 runner/plugin/assets 자체 보유 |
| CSI | 일반 화면은 상태·기존 모델 선택·추론 시작/중지. 수집/학습 화면은 개발 모드에만 노출. 제품 service에는 `--inference-only` 추가 |
| 시나리오/장치 시험 | 일반 화면에서 숨김. `SAFEHUB_DEVELOPER_TOOLS=true` 빌드에서만 노출. 실제 사건·터치/수어 도움은 유지 |
| 문맥 설명 | 기본 모델 `fasttext-fire-screen`, 설정 UI도 fastText 고정. 생성형 서버/프로파일러 삭제. 기존 생성형 설정은 파일을 바꾸지 않고 메모리에서 설명을 꺼 자동 호출 방지 |
| 가전 | 팬·커튼과 필요한 수어 단축키. LED·진동은 기존 경보 흐름 유지. 미지원 조명 카드는 제외하고 기존 light 단축키 파일 내용은 비활성 설정으로 보존 |
| 과거/개발 소스 | 독립 CSI 데스크톱 앱과 `SW/rpi4_vision` 모의 구현 삭제. 현재 C6 소스는 `HW/esp32_csi`로 분리 보존. 현재 수어 회귀에 필요한 Python 기준 코드·fixture와 Windows/CSI 개발 도구는 유지 |

새 UI 안에 남아 있던 미사용 옛 dashboard/header/room/alert 레이아웃과 그 전용 helper도
정적 참조를 대조해 제거했다. 현재 홈·레이아웃 편집·카메라·음성자막·도움 흐름은 회귀 검사로
확인했다. extension의 setState 호출은 State 내부 메서드로 옮겨 보호 멤버 접근도 정리했다.

수어 기준 파일 `07g_webcam_15class_final_frozen.py`와 그 참조 모듈·reference 디렉터리는
C++ golden fixture 생성기와 offline_sign_pipeline 등이 실제 사용하므로 삭제하지 않았다.
개발/회귀 자료이며 제품 부팅 대상이 아니다. C6 소스·설정·라이선스 9개는 백업과 같은
SHA256임을 `HW/esp32_csi/SOURCE_PROVENANCE.json`에 기록했다. 과거 bin 산출물은 재추가하지 않았다.

## 제품·개발 실행 경계

| 구성 | APP_LOCAL_PREVIEW | SAFEHUB_DEVELOPER_TOOLS |
|---|---|---|
| 실제 연결용 제품 빌드 | false | false |
| 실제 연결용 개발 빌드 | false | true |
| 장비 없는 제품 화면 미리보기 | true | false |
| 장비 없는 시연/개발 화면 | true | true |

`SAFEHUB_DEVELOPER_TOOLS`는 화면 노출이며 실제 I/O를 차단하는 스위치가 아니다.
실제 연결용 개발 빌드의 장치 시험은 실제 명령을 낼 수 있다. 이번에는 장비에 실행하지 않았다.
일반 빌드는 두 플래그 모두 false이며, 브라우저/Windows 준비 도구는 개발 도구 false를
명시한다. 브라우저에서 `--developer-tools`를 추가하면 시연·CSI 개발 화면을 볼 수 있다.

```sh
python3 SW/safehub_scenario/tool/run_ui_preview.py --check-only
python3 SW/safehub_scenario/tool/run_ui_preview.py
# 시연/개발 화면을 포함할 때만
python3 SW/safehub_scenario/tool/run_ui_preview.py --developer-tools
```

실제 연결용 개발 빌드는 `--dart-define=SAFEHUB_DEVELOPER_TOOLS=true`를 명시한다.
앱 package/binary는 여전히 `safehub_app`, 설치 ID는 `com.atlas.app.safehub_scenario_pr7`이다.
후보 버전은 1.4.0+1/manifest 1.4.0을 유지한다. 이는 설치된 실행본과의 대응 증거가 아니다.

제품 CSI의 `--inference-only`는 connect/disconnect, 기존 모델 select_model,
recognize/stop_recognition만 허용한다. capture/train/기록·모델 가져오기/삭제·내보내기 등은
거절한다. 준비된 모델 선택은 메모리의 추론 구성만 바꾸며 모델 파일을 학습/교체하지 않는다.
이 옵션은 `--allow-training`과 함께 사용할 수 없다. 개발용 Python 서비스·Windows 런처는
별도 개발 도구로 남겨 두며 그 학습 기능을 제품 서비스에 적용하지 않는다.

`aircon`이라는 기존 MQTT device ID/토픽과 인식 라벨은 팬 연결 계약 때문에 유지한다.
화면은 팬이라고 표시하며 임의 토픽 이름 변경을 하지 않았다. 팬/커튼의 명령 제출과 실제
회전/위치 확인을 구분한다. LED·진동의 활성화/ON·OFF action/지역/MQTT 조건도 유지한다.

## fastText와 기존 설정

새 설정의 모델은 fastText이며 기존 endpoint·주소·LED 설정을 임의 파일 삭제로 초기화하지 않는다.
저장 파일에 다른 모델 또는 과거 느린 프로토콜이 있으면 설명을 메모리에서 꺼 둔다.
설정 화면에서 실제 fastText 주소·모델 확보를 확인한 뒤 사용자가 켤 수 있다.
기존 프로토콜 파서/안전 검사는 호환 회귀 자료로 유지하되 제품 설정 UI는 fastText 경로만 저장한다.
선택적인 인증 변수도 `SAFEHUB_CONTEXT_API_KEY`로 구분하여 과거 LLM 키를 자동 전송하지 않는다.

실제 `fire_screen_model.bin`·장치 런타임·모델 체크섬은 미확인/미확보다.
가짜 모델 규칙/HTTP 검사와 실제 fastText native import/tokenize 검사를 구분한다.
실제 모델을 임의 학습하거나 교체하지 않았다. opt-in 실제 연동 검사는
`SAFEHUB_LIVE_FASTTEXT_TEST=1`이 명시된 때만 실행하며 이번에는 skip이다.

## 검증과 체크포인트

- 최종 전체 Flutter **271 pass / 0 fail / 1 opt-in 실제 fastText skip**, exit 0.
  개발 플래그 true로 기본 진입/시나리오 경로도 **6개 통과**했다.
- CSI Python **54/54**: 제품 명령 제한, 기존 모델 선택, CLI 모드 전달·충돌 거절,
  기존 합성 수집·학습·추론/serial mock/데이터 검사를 포함한다. 실제 센서 정확도 시험 아님.
- 소스 패키징 **5/5**, Windows Python 도구 **14/14**.
- 옛 경로 제거 후 CMake configure/build와 수어 CTest **19/19** 통과.
- 제품 화면 preview web release 빌드 exit 0. ATLAS/Windows 네이티브 컴파일이 아니다.
- 최종 정적 분석 **error 0 / warning 0 / info 103, exit 1**.
  남은 스타일 안내를 깨끗한 분석 통과로 표시하지 않는다.
- 최초 CSI 전체 검사 실패는 새 inference_only 인수를 반영하지 않은 CLI mock 기대였다.
  새 제품 모드 전달 사례까지 포함해 수정했다. 새 모델 선택 widget fixture도 실제 서비스처럼
  선택 시 인식을 정지하도록 고쳤다. 안전 검사를 skip하거나 삭제해서 통과시키지 않았다.
- 로그는 `/workspace/.cloud-setup/product-cleanup-*`에 보존했다.
  검사 호스트와 최종 lib/test **93개 파일 바이트 일치**를 확인했다.
  환경 시작 안내 초안도 승인된 제품 모드 기준으로 저장했다. 설치 스크립트와 기존 의존성은
  보존했다. 초안 저장은 게시·새 환경 복원 검증을 뜻하지 않는다.
- 주요 커밋: `4074535` 과거 앱 삭제, `62cc5f1` 현재 C6 소스 보존,
  `82b9a3c` 제품/개발 UI와 fastText, `5076dd8` 제품 CSI 제한,
  `8907ded` 호스트 기본 모드 통일. 각 단위는 Git에서 복원 가능하다.

#6 안정화와 #9/#10 포함 관계는 [이전 기능별 검토](pr10-addendum-review.md)를 유지한다.
1.2.0은 과거 사용자 확인, 1.4.0 설치는 #10 작성자 보고이며 현재 장치는 직접 확인하지 않았다.
ATLAS 패키지·ARM64/ABI 독립 재현·실제 모델·부팅·마이크→장치·모터·펌웨어 실행은 미검증이다.
main/develop 직접 반영, 기존 PR 병합/닫기/삭제, 실제 서비스 제어·실행본 교체·플래시는 하지 않았다.
