# 위험 안내 음성과 TTS 연결

2026-10-27, 로컬 작업 브랜치 `feature/pr11-device-20261027`에 반영.
이 문서의 변경은 아직 GitHub에 push하지 않았다.

## 동작

- 방송, YAMNet 경보음, 재난 API, 도움/낙상 의심 이벤트가 활성화되면 해당 내장 음성 1회 재생.
- 화면 테스트는 무음. 실제 장치 시나리오 테스트는 음성도 재생.
- 동일 사건의 상태 갱신과 MQTT 재연결은 음성을 반복하지 않음.
- 더 높은 우선순위 사건이 오면 이전 재생을 취소. 확인·도움 취소·테스트 종료 시 재생 취소.
- 상세 화면의 `빛·진동·음성 다시 알림`으로 수동 재생 가능.
- 일반 수어 TTS는 사건이 활성화된 동안 보류. 위험 안내는 일반 TTS 서버 URL이 비어 있어도 작동.
- 문구는 확인을 요청하며 사이렌·CSI만으로 화재·의식불명·발생 장소를 확정하지 않음.

## ATLAS 오디오

기존 AudioPlayer 경로에서 응답이 완료되지 않는 timeout을 실제 앱 로그로 확인했다.
또한 BytesSource의 Linux 임시 파일 경로는 이 앱에 없는 path_provider를 요구한다.
ATLAS에서는 비동기 `gst-launch-1.0`의 decodebin·PulseAudio 경로로 바이트를
임시 파일에서 재생한다. 앱 UI 스레드에서 동기 DBus 호출을 기다리지 않는다.
재생 시작 메시지를 확인하고, 종료·실패·취소를 처리한다.
기존 Windows AudioPlayer 경로는 유지한다.

## TTS 설정

`장비 · 서버 연결 설정 → 스피커 음성 출력 · TTS → TTS 서버 주소`

Pi5 앱과 서버가 같은 장치에 있으면 `http://127.0.0.1:8000`.
`/tts`는 앱이 붙이므로 입력하지 않는다. 연결 확인은 `/health`만 조회하며
합성·스피커 성공을 의미하지 않는다. 저장은 사용자가 수행한다.

일반 문장 TTS의 edge-tts 7.2.8 실제 요청은 HTTP 403으로 실패했고,
7.3.1에서 같은 고정 문장의 합성이 성공했다. 패키지 변경은 격리된
`/opt/safehub-tts/venv`에 적용했다. STT 환경과 모델을 변경하지 않았다.
이 일반 합성에는 인터넷이 필요하다. 위험 안내 MP3는 미리 생성한 고정 문구다.

## 검증

- 위험 음성·수어 TTS·시나리오 경로·오디오 기존 경로: 최초 32개 테스트 통과.
- 시나리오·도움·홈·제어 회귀: 22개 통과.
- 최종 변경의 프로세스 오디오·위험 음성·오디오·TTS 설정·HTTP 클라이언트: 39개 통과.
  위 검사 집합은 일부 겹치므로 합계를 고유 테스트 수로 쓰지 않는다.
- 실제 Pi5 Python 3.12의 TTS ASGI 계약 검사: 8개 통과(fake 합성기).
- 실제 `/tts`: 18,720바이트 MP3 생성, `/health` 정상.
- 앱 1.5.7: 모의 MQTT 낙상 이벤트 수신 → 위험 음성 재생 완료 로그 →
  `SafeHub speech` PulseAudio 스트림을 관찰.
- 사용자 저장 URL 확인 후 고정 번역 테스트 문장 → 서버 합성 →
  같은 SafeHub 스트림 생성 확인.

모의 이벤트는 실제 CSI 낙상 검출 결과가 아니다. 오디오 스트림 관찰은
물리 스피커의 가청성 확인과 다르다. LED·진동 물리 동작과 재부팅 시험은
이번 검증에 포함하지 않았다. 현재 출력 장치는 HDMI 기본 sink였다.

### USB 헤드셋 경로 수정

이후 사용자 청취 시험에서 무음이 확인됐다. PulseAudio 기본 출력을 USB로
바꿔도 SafeHub의 새 음성 스트림이 HDMI sink 1로 연결되는 현상을 관찰했다.
해당 스트림을 USB sink 0으로 옮기자 USB playback이 실제 Running으로
전환됐고 사용자가 확인 음성을 들었다고 응답했다.

사용자의 '모든 출력을 헤드셋으로' 요청에 따라 HDMI 오디오 카드 profile을
off로 바꾸고 USB GeneralPlus를 유일한 출력으로 남겼다. 헤드셋 마이크
기본 source는 유지했다. `route-headset.sh`와 `safehub-audio-output.service`를
설치하고 기존 bootstrap의 선택 서비스 목록에 추가했다. USB가 없는 경우
스크립트는 다른 출력을 끄지 않는다. 실제 재부팅 시험은 수행하지 않았다.
부팅 스크립트 백업: `/opt/safehub-system/backups/before-audio-20261027-230339`.

## 배포와 복구

배포 경로: `/data/safehub-pr7/releases/emergency-speech-20261027-r3`.
앱 ID: `com.atlas.app.safehub_scenario_pr7`, 버전 1.5.7.
네이티브 runner·기존 기능 파일은 패키지 기반으로 보존했다.
설치 시 프로필 JSON 3개의 해시가 유지됨을 확인했다.

작업 전 1.5.4 앱·프로필 백업:
`/data/safehub-pr7/releases/emergency-speech-20261027/before-20261027-221714/app-and-profile.tar.gz`.
후속 배포마다 각 release의 `before-*`에도 백업이 있다.
TTS 부팅 설정 원본은 `/opt/safehub-tts/before-*`에 있다.

앱 복구는 AppManager로 중지한 뒤 기존 1.5.4 IPK를 PackageManager로
설치하고 다시 시작한다. 프로필은 현재 것을 유지하며, 필요 시에만
백업 archive의 profile을 임시 폴더에 풀어 현재 설정과 비교한다.
원본 archive를 앱 경로에 바로 풀거나 새 설정을 무조건 덮어쓰지 않는다.
