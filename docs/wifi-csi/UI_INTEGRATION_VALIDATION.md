# 통합 개발본 검사 결과

검사일: 2026-10-04 (Asia/Seoul)

## 기준

- UI 기준: 팀 feature/SW, commit `110a09e3063d629bc54676d157d940c347ebd1a5`
- 로컬 작업 브랜치: `feature/wifi-sensing-ui`, 개인 fork를 origin으로 사용
- CSI 기준: 노트북 WifiSensing2-src의 실행 소스 29개. runtime/LOCAL_SOURCE_MANIFEST.json으로 파일별 일치 확인
- Python: 노트북의 기존 Python 3.12 환경, torch 2.7.1+cpu, NumPy 2.2.6
- UI 검사 도구: Flutter 3.29.3 / Dart 3.7.2, Windows 호스트
- 원래 WifiSensing2.0 EXE/측정 기록/모델: 변경하지 않음
- 제출 대상: 개인 fork의 `feature/wifi-sensing-ui` → 팀 저장소 `develop`. 병합은 팀 리뷰 후 결정한다.

## 통과한 검사

Python 통합 검사 **10개 통과**:

1. 최신 노트북 소스 및 upstream 소스 해시 일치
2. 표시 파형과 최신 엔진 출력 일치, 단계 토글 적용
3. 시간 지정 수집·저장, 일괄 삭제·복원, 세션 캐시 해제
4. 입력 공백 시 이전 파형/판단 제거 및 진행 중 수집 실패 처리
5. 재연결/시간 epoch 변경 후 이전 수집이 완료되지 않음
6. 합성 기록으로 실제 100 epoch CNN 학습, 선택 ID/회차별 분리 확인, 저장 학습 입력과 전처리 일치, 모델 ZIP 내보내기/가져오기, PC/NumPy 추론 점수 오차 1e-5 이내
7. Pi 모드 학습 거부 및 모의/실측 모델·기록 혼합 거부
8. 실제 로컬 HTTP 요청 형식 및 브라우저 Origin 변경 요청 거부
9. 목록 조회에서 원본 I/Q 파일 반복 읽기 방지, 실시간 버퍼 8400프레임 제한
10. 전처리 도중 연결 해제되면 이전 파형을 응답하지 않음

Flutter 위젯 검사 **5개 통과**:

- 단계 토글과 체크한 기록 ID가 올바른 API 요청으로 전달됨
- 1280×720 및 600×800 크기에서 화면 overflow 없음
- API 연결 실패 시 이전 행동 결과가 화면에서 사라짐
- 한국어 글꼴/아이콘을 로드한 센싱 화면 렌더링 및 PNG 확인

프로세스 검사 통과: 실제 bridge 프로세스 시작 → HTTP 모의 신호 연결 → 240시점 실시간 전처리 → 3초 준비/4초 수집 → 저장 → 연결 해제/결과 초기화. 임시 테스트 데이터와 프로세스는 정리됨.

추가한 UI 파일의 정적 검사: 오류/경고 없음. 전체 UI를 호스트용 테스트 복사본에서 검사했을 때 오류/경고는 없고, 기존 코드의 deprecated API 안내 8건이 있음. ATLAS 전용 오디오 플러그인 두 개는 호스트 테스트 복사본의 의존성에서만 제외했으며 저장소의 실제 pubspec은 변경하지 않음.

## 근거

- [Python 검사 로그](integration-validation/python-tests.log)
- [Flutter 검사 로그](integration-validation/flutter-tests.log)
- [실제 프로세스 검사](integration-validation/http-smoke.json)
- [모의 데이터 화면](integration-validation/wifi-panel-synthetic.png)

## Windows 체험 실행 확인 (2026-10-04 00:41 KST)

- `APP_LOCAL_PREVIEW=true` 설정 검사 및 1280×900 홈 → 센싱 페이지 → 종료 위젯 검사 2개 통과. production 기본 빌드의 필수 설정 거부도 확인했다.
- Windows x64 Release 실행파일 빌드 완료. Flutter 3.29.3, VS 2026/MSVC 19.51, SDK 10.0.26100.0을 사용했다. 호스트 복사본에서만 ATLAS 플러그인 두 개를 제외했고, Windows 오디오/녹음 플러그인은 포함했다.
- 설치된 VS 2026에 맞춰 CMake generator를 직접 선택했다. 오디오 플러그인의 기존 coroutine 구현에는 MSVC 문서화된 폐기 예정 안내 억제 정의를 호스트 빌드에만 적용했다. SDK/Pub 캐시 소스와 production pubspec은 수정하지 않았다.
- 로컬 Windows 실행기 검사 통과: 잘못된 설정, 점유 포트 보호, 중복 실행 방지, 경로 인수 처리, 자신이 시작한 자식만 종료하는 Job Object.
- 실제 실행기 → Python 서비스(`/state`) → Flutter 앱 시작 성공. 서비스 준비 13.6초, 한국어 홈 화면과 체험 안내/장비 미연결 표시를 실제 창에서 확인했다.
- 시작 시 파형 없음, 수집 기록 0개, 인식 중지/결과 없음 확인. 모의 신호를 자동 시작하지 않는다.
- 바탕화면 `SafeHub-통합체험` 폴더의 별도 기록을 사용한다. 이 노트북의 기존 Python 환경을 참조하는 체험본으로, 다른 PC/Pi용 독립 설치본은 아니다.

## 아직 하지 않은 검사

- 실제 C6 RX USB 수신/분리/복구와 펌웨어 형식 확인
- Pi 4/5 또는 ATLAS에서 의존성 설치·ARM64 빌드·실행
- 카메라 수어 인식과 CSI의 실기기 동시 운전
- 실측 행동 정확도·오탐·독립 환경 평가, CPU/RAM/지연/장시간 운전
- 기존 전역 안전 경보/MQTT/액추에이터 연결
- Pi/ATLAS 최종 실행파일·장비 설치 패키지 및 다른 PC용 독립 배포본 생성

합성 기록의 학습 점수는 실제 행동 인식 정확도가 아닙니다. 이 결과는 코드 경로와 UI 조작의 통합 검사에 한정됩니다.
