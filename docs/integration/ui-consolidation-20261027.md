> 여섯 권장안은 사용자 승인 후 적용했습니다. 현재 결과·복구 지점은
> [제품 통합 기록](product-scope-20261027.md)을 기준으로 합니다. 아래는 승인 전 정리 기록입니다.

# 현재 UI 기준 소스 정리와 결정 목록

기존 PR #11에서 계속 작업했다. 시작 SHA는 `654e2f3cb09a1778d65ba6554bc35b94e1679e6e`이며
미커밋·미추적 파일은 없었다. `/workspace/.cloud-setup/ui-consolidation-preservation-20261027/before-cleanup.bundle`에
보존했다. 새 환경·새 PR을 만들지 않았다.

## 확인 없이 완료한 범위

1. 현재 개발/빌드/문서 진입점을 `SW/safehub_scenario`로 통일했다.
   root README·Scenario 안내·Windows 안내·부팅 점검의 옛 ID/검사 수치/병행 실행 설명을 정리했다.
   옛 UI는 기본 실행 대상이 아니라는 안내를 별도로 남겼다.
2. Scenario의 `atlas/`, `third_party/record_atlas/`, assets, lib가 자체 경로에 있음을 확인했다.
   runner CMake와 pubspec은 옛 `SW/safehub_app`의 소스를 참조하지 않는다.
   `safehub_app`은 package/binary 이름이기도 하므로 그 문자열을 일괄 치환하지 않았다.
   audioplayers_atlas SDK는 여전히 외부 전제이며 ATLAS 빌드/ABI는 미검증이다.
3. 호스트 준비 도구의 `SW/wifi_sensing/prepare_ui_tests.py` import를 제거했다.
   Scenario 내부 `tool/host_support.py`에 전체 호스트 준비 기능을 두었다.
   CSI 전용 최소 호스트와 옛 UI 도구는 현재 UI의 실행/검사 전제가 아니다.
4. 테스트·브라우저·Windows 도구가 pubspec의 ATLAS path dependency 제거 함수를 공유한다.
   복사한 lib/test/assets는 원본 그대로이며 제품 기능·개인 설정·기본 장치 동작은 바꾸지 않았다.
5. Windows 준비/오디오 패치는 출력이 저장소 어디에도 들어가지 못하도록 보완했다.
   기존 파일·사용자 override·플러그인 해시 검사를 유지한다. 생성 호스트 제목은 현재 Scenario로 맞췄다.
6. 과거 Windows ZIP/설치 기록을 현재 후보의 검증 결과와 구별했다.
   #10 장치 테스트가 실제 명령을 낼 수 있는데도 “모든 테스트는 명령 없음”으로 읽히던 설명을 고쳤다.

## 사용자 결정이 필요한 범위

아래 항목은 현재 코드에서 삭제/숨김/서비스 중단하지 않았다. 권장안은 제안이며 승인으로 취급하지 않는다.
응답 전에도 위 준비·검증·PR 갱신은 완료한다.

| 번호 | 결정할 내용 | 선택지 / 제안 | 영향 |
|---|---|---|---|
| 1 | 옛 UI 소스 `SW/safehub_app`의 최종 삭제 | **삭제 권장** / 당분간 별도 보존 | 현재 UI의 직접 의존성은 없음. 소스 이력/복구 checkpoint는 유지하고 장치 설치본에는 손대지 않음 |
| 2 | CSI 화면과 서비스 범위 | 전체 유지 / **상태·추론만 제품에, 수집·학습은 개발용** / 전체 제외 | 수집·학습 화면, 서비스·부팅 의존성을 함께 정리해야 함. Python 공유 런타임을 통째로 지우면 안 됨 |
| 3 | 시나리오·수어 입력·실제 장치 테스트 UI 노출 | **개발·시연 모드에만** / 일반 화면에도 / 제거 | 실제 경보 처리와 수어·터치 도움은 유지. 테스트 창의 모터 명령 가능 여부를 숨김 정책과 함께 정해야 함 |
| 4 | 문맥 설명 엔진 | **#10 fastText 기반 설명 유지** / 생성형 LLM도 선택적으로 유지 / 설명 자체 제외 | 자막(STT)과 즉시 경보는 별개. fastText 실제 모델은 미확인/미확보이며 사용자 모델 대체·재학습 금지 |
| 5 | 제품 가전 범위 | **팬·커튼·LED/진동과 필요한 수어 단축키** / 기존 가전 화면 전체 유지 | 미완료 ThinQ·Home Assistant 경로를 제품 안내에서 어디까지 빼고, 사용 중인 추가 IR/스위치 기능을 남길지 결정 |
| 6 | 개발·과거 소스가 GitHub에 남을 범위 | **개발/회귀 도구는 구분해 유지, 옛 독립 앱·실험은 삭제 후보 검토** / 모두 유지 / 제품 소스만 유지 | Windows 도구, WiFi-CSI-Sensing 독립 앱, rpi4_vision 대안, 루트 실험·reference 데이터. 회귀 fixture와 실제 C++ 의존성은 확인 후 선별 |

## 검증과 경계

- Scenario 재현 검사 **5/5 통과**. 옛 UI와 wifi_sensing 폴더가 전혀 없는 임시 복사본에서
  실제 test-host 준비와 browser `--check-only` 실행을 확인했다. 소스·자산 바이트 일치,
  manifest/package/launcher 식별, ignore 예외, 잘못된 출력 경로 거절도 확인했다.
- Windows Python 도구 **14/14 통과**. 준비 preflight와 저장소 전체 보호를 포함한다.
  Windows 실행 파일 컴파일/실행 결과로 세지 않는다.
- 새 호스트 도구로 preview web release 빌드도 **exit 0**으로 통과했다.
  `ui-cleanup-web-build.log`에 기록했다. ATLAS/Windows 네이티브 빌드 결과는 아니다.
- 문서의 로컬 링크와 전체 diff 공백 검사도 통과했다. 환경 설정 초안의 시작 안내도
  새 UI를 기본으로 바꾸고 기존 CSI 안내는 선택적인 개발 절차로 보존했다. 게시/새 환경 복원 검증은 하지 않았다.
- Dart 제품 코드·테스트·의존성 버전은 변경하지 않았다. 기존 전체 Flutter 265 pass/1 skip,
  후속 영향 경로 13 pass는 [이전 검토 기록](pr10-addendum-review.md)의 결과로 유지한다.
  이번 변경으로 그 전체 검사를 새로 실행한 것처럼 표시하지 않는다.
- 현재 소스 후보 1.4.0+1, 앱 ID `com.atlas.app.safehub_scenario_pr7`을 유지한다.
  1.2.0은 과거 사용자 확인, 설치 1.4.0은 #10 작성자 보고, 현재 장치 상태는 미확인이다.
- 실제 장치·모델·보관본은 미확인/미확보이며 없다고 단정하지 않는다.
  ATLAS 빌드·재부팅·마이크→실제 장치·모터·모델 정확도는 검증하지 않았다.
- main/develop 직접 반영·기존 PR 닫기·장치 실행본 교체·서비스 제어·펌웨어 플래시는 하지 않았다.
  최종 폴더 삭제와 제품 기능 축소는 위 결정이 반영된 뒤 검토한다.
