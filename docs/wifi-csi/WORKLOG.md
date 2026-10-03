# Wi-Fi CSI 작업 기록

Notion 개발 문서: [CSI](https://app.notion.com/p/CSI-a080797e801c4a31a3fe03d9efd5e3b5)

## 2026-10-04 · SafeHub UI 통합

기존 수어 홈에 와이파이 센싱 화면을 추가했다. 최신 52채널/PCA 1성분 엔진으로 실시간 파형, 행동 기록, 선택 학습, 현재 행동 판단을 연결했다. Windows에서는 장비 없이 모의 신호로 흐름을 확인할 수 있는 체험 실행기를 만들었다.

Python 통합 검사 10개, Flutter 센싱 검사 5개, 체험 모드 검사 2개가 통과했다. Windows Release 실행과 로컬 서비스 연결을 확인했다. Pi·카메라·터치디스플레이·스피커 동시 운전과 MQTT 안전 경보 연결은 장비 연결 후 확인한다.

제출: 개인 fork의 `feature/wifi-sensing-ui`에서 팀 `develop` 대상 Draft PR. 기반인 `feature/SW`가 아직 develop에 없으므로, 기존 SW 변경과 이번 CSI 추가를 구분해 검토한다. 자세한 범위는 [통합 검증 기록](UI_INTEGRATION_VALIDATION.md)을 참고한다. Notion에는 아직 반영하지 않았다.

아래는 2026-09-15 독립 CSI 모듈 제출 당시 기록이다.

## 변경 범위

- WiFi-CSI-Sensing을 팀 프로젝트 안의 독립 모듈로 배치
- 프로젝트 소개, 협업 규칙 및 MQTT 연동 범위 문서 추가
- Python 코드의 들여쓰기·공백·문장 분리와 미사용 import 정리
- 라이브러리 재정의 메서드를 제외한 snake_case 명명 검사
- 개인 측정 기록·모델·비밀번호·장치 로그 제외

## 이번 작업에서 유지하는 규격

기존 전처리 프로파일, 기록 JSON 형식, 모델 클래스 이름과 MQTT 명세를 유지합니다. 팀장 main에 직접 commit·push하거나 다른 팀의 브랜치를 merge하지 않습니다.

## 검증 기록

확인 시각: 2026-09-15T14:43:30+09:00

소스 기능 검사 194개와 Ruff 검사가 통과했습니다. Python 24파일의 AST 비교에서 미사용 import 정리 외 처리 로직이 동일했습니다. 실제 C6·Pi 행동 실험은 수행하지 않았습니다. 상세 기록은 VALIDATION.json에 있습니다.

기존 Windows 배포본은 별도 산출물이며 이번 소스 형식 정리 뒤 다시 빌드하지 않았습니다.

## 다음 작업

팀원 리뷰에서 공통 Python 환경과 의존성을 확인하고, C6 두 대의 실측 및 Pi 성능을 검증합니다. MQTT 이벤트 연결은 INTEGRATION.md의 협의 항목이 확정된 뒤 별도 기능으로 진행합니다.
