> 이전 PR #8 중심 검토의 역사 기록입니다. 현재 판단·범위·검증은 [PR #10 추가 통합 기록](pr10-addendum-review.md)이 우선합니다.

PR #8 기반 Scenario UI에서 재전송 안전 이벤트가 중복되거나 카메라 연결 해제 후 늦은 이미지가 표시되는 문제를 보완하는 검토 후보입니다. #6의 필요한 STT 부팅, MQTT ID 중복/등록 순서/QoS, 카메라 수명, 오디오 응답 대기 제한을 새 `SW/safehub_scenario`에 기능별로 이관했습니다. #7은 #8의 조상에 이미 포함돼 있습니다.

앱 ID `com.atlas.app.safehub_scenario_pr7`을 유지하고 Scenario runner·manifest·호스트 준비 도구·ignore 예외·관찰된 통신 명세를 정리했습니다. 1.2.0 표기는 사용자 확인 기준에 맞춘 후보 버전이며, 설치 IPK와의 소스 대응이나 ATLAS 빌드를 입증하지 않습니다. 새 장치 테스트 창과 자동 물리 출력 변경은 포함하지 않았습니다.

- 새 Scenario 전체 Flutter 테스트 **243 pass / 0 fail / 1 skip**(기존 opt-in live LLM). Flutter 3.35.7 / Dart 3.9.2와 동결 host lock으로 실행했고 preview web release 빌드도 통과했습니다.
- 직접 통과: boot stub 4개, source packaging 3개(새 clone에서도 확인), Windows Python 도구 11개, 전체 diff/셸 구문 검사.
- 별도 SHA 검토: #9 `ae887ac`의 x86_64 C++ 회귀 19개와 Python 3개, #10 `da7248f`의 Uno/shortcut 14개와 context 규칙 6개, 보류한 #6 offline adapter 8개 통과. 이 수치를 통합 앱 통과 수로 합산하지 않습니다.
- 정적 분석: **0 error / 11 warning / 93 info, exit 1**. 같은 SDK/lock으로 PR #8 원본과 대조해 새 warning/error signature는 0개입니다. 기존 경고를 통과로 표시하거나 무관한 UI helper를 지워 숨기지 않았습니다. 실제 ATLAS runner/link/IPK 빌드는 별도 전제입니다.
- 최초 13개 실패를 조사해 옛 화면 선택자·도움 모달·일반 수어 응답 기대를 현재 UI에 맞췄고, MQTT fixture의 별도 socket write future에 남는 의도적 reset 오류를 처리했습니다. 안전 검사·메시지/재시도 검사는 유지하며 [후보 화면](scenario-host-captures/demo-home.png)도 확인했습니다.
- #9는 별도 후보로 유지합니다. 기존 보고서의 ARM64 빌드·정적 ABI 통과와 이번 호스트 결과를 구분했으며, 대상 라이브러리 수집본이 없어 ARM64/ABI 독립 재현과 실제 카메라/모델 실행은 미검증입니다.
- 명준이의 새 Arduino 작업은 #10으로 수신·검토했습니다. Uno 스케치/보드 빌드 명세는 미수신이고, 새 창·커튼/자동 경보 연결은 이번 후보에 채택하지 않았습니다. 물리 동작 완료 ACK와 watchdog도 별도 확인 대상입니다.

기존 체크아웃과 ignored 파일은 전체 백업했고 원래 develop 작업 폴더를 보존했습니다. main/develop 직접 반영, 기존 PR 병합·닫기·삭제, 장치 교체·서비스 제어·펌웨어 플래시는 하지 않았습니다.

근거와 후속 확인: [고정 SHA·채택 판단·검증](scenario-review-20261026.md), [재현 및 적용·복원 준비](scenario-reproduction-20261026.md), [기계 판독 검증 범위](scenario-review-evidence-20261026.json).
