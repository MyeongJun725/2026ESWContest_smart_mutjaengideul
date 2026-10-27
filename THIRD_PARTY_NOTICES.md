# 외부 소스와 라이선스

프로젝트 전체에 새 라이선스를 일괄 부여하지 않습니다. 외부 소스의 원래 고지와
아래 라이선스를 각각 유지합니다. 비공개 ATLAS SDK·모델은 저장소에 포함하지 않습니다.

| 구성 | 출처와 유지한 고지 |
|---|---|
| Pretendard 폰트 | [공식 저장소](https://github.com/orioncactus/pretendard), [OFL 전문](SW/safehub_scenario/assets/fonts/OFL.txt). 현재 폰트 이름/파일을 유지하며 OFL 전문도 앱 asset으로 포함 |
| ATLAS runner의 Flutter embedded template | 기존 runner의 Sony 저작권 주석 유지. [공식 upstream](https://github.com/sony/flutter-embedded-linux)의 [BSD 라이선스](SW/safehub_scenario/atlas/LICENSE)를 추가 보존하고 CMake 설치 시 licenses 폴더에 포함 |
| record_atlas | [기존 라이선스](SW/safehub_scenario/third_party/record_atlas/LICENSE), [record_linux 원본 고지](SW/safehub_scenario/third_party/record_atlas/LICENSE.record_linux) |
| CSI Python runtime | [출처](SW/wifi_sensing/runtime/NOTICE.md), [MIT](SW/wifi_sensing/runtime/LICENSE), [의존성 고지](SW/wifi_sensing/runtime/THIRD_PARTY_NOTICES.txt), 기존 소스 해시 검증 유지 |
| ESP32-C6 | [보존 출처와 해시](HW/esp32_csi/SOURCE_PROVENANCE.json), [C6 라이선스](HW/esp32_csi/LICENSE-C6.txt), [ESP-IDF](HW/esp32_csi/ESP-IDF-LICENSE.txt) |
| Windows 오디오 수정 | [패치 안내](SW/windows_preview/README.md), [audioplayers_windows MIT](SW/windows_preview/licenses/audioplayers_windows-MIT.txt). 원본 package/라이선스 해시 확인 후 독립 host 사본만 수정 |

이번에 보완한 폰트·runner 라이선스는 upstream commit·원문 URL·SHA256을
[THIRD_PARTY_SOURCES.json](SW/safehub_scenario/THIRD_PARTY_SOURCES.json)에 기록했습니다.
원문을 바꾸지 않았으며 ATLAS 자체 SDK의 재배포 권한이나 실제 패키지 빌드 성공을 뜻하지 않습니다.
Python/Flutter/C++ 의존성은 해당 배포본의 라이선스와 고지를 따릅니다.
