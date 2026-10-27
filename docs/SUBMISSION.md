# GitHub 제출 확인

현재 제품 소스는 `integration/scenario-stability-20261026`, 검토 PR은
[#11](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/pull/11)입니다.
PR #10(#8/#7 포함), #9 소스 후보와 #6의 필요한 안정화를 통합했습니다.
최신 UI는 `SW/safehub_scenario`이며 옛 UI를 함께 실행하지 않습니다.
최신 [소스 포함 관계·미사용 정리·외부 준비 목록](integration/final-source-audit-20261027.md)을
먼저 확인하세요. 공개 PR 통합 완료와 실제 장치 전체 재현 완료는 다릅니다.

## 제출 직전 확인할 것

1. **제출 대상 브랜치와 SHA:** 대회가 main을 읽는다면 현재 PR 브랜치만 push한 상태와 다릅니다.
   main/develop 직접 반영·최종 병합은 사용자 지시 전에는 하지 않았습니다.
   PR의 head와 실제 제출할 ref를 확정한 뒤 해당 코드의 README·검사 결과를 확인하세요.
2. **검증 범위:** PR Checks의 GitHub 실행 결과와 [직접 실행 기록](integration/submission-audit-20261027.md)을
   구분합니다. CI의 fake 모델·loopback·C++ fixture는 실제 장치 시험이 아닙니다.
   스타일 info는 출력하며 기능 오류/경고는 실패 처리합니다.
3. **실행 자료:** ATLAS SDK·runner/plugin·IPK/ELF와 실제 설치 소스 대응,
   fastText 실제 모델/해시·Uno 스케치·펌웨어와 장치 설정 보관본을 확보해야 실기 재현을 판단할 수 있습니다.
   현재 미확인/미확보 항목을 “없음”이나 “실물 통과”로 바꾸지 않습니다.
4. **재현 안내와 출처:** root README의 장비 없는 제품 화면 경로와
   [외부 소스 고지](../THIRD_PARTY_NOTICES.md)를 사용합니다. 비공개 SDK·개인 데이터는 제출 소스에 넣지 않습니다.
5. **복구 지점:** [백업 브랜치](https://github.com/minbeom77/2026ESWContest_smart_mutjaengideul/tree/backup/pr11-before-product-cleanup-20261027)와
   [복원 절차](integration/product-scope-20261027.md)를 유지합니다. 정리 전 847개 파일 복원 검사를 완료했습니다.

## 비장비 소스 검사 명령

Python 3.12의 저장소 밖 가상 환경에서 필요한 가벼운 검사 의존성만 설치합니다.
CSI 학습 스택과 실제 fastText 모델을 이 검사 때문에 설치할 필요는 없습니다.

```sh
python3 tools/audit_product_sources.py
python3 -m venv /tmp/safehub-checks
/tmp/safehub-checks/bin/python -m pip install -r tools/requirements-checks.txt
/tmp/safehub-checks/bin/python -m unittest discover -s SW/tts_server/tests -p 'test_*.py' -v
/tmp/safehub-checks/bin/python -m unittest discover -s SW/safehub_scenario/tool -p 'test_*.py' -v
/tmp/safehub-checks/bin/python -m unittest discover -s SW/fasttext_context/tests -p 'test_*.py' -v
/tmp/safehub-checks/bin/python -m unittest discover -s SW/uno_bridge/tests -p 'test_*.py' -v
/tmp/safehub-checks/bin/python -m unittest discover -s SW/rpi4_vision_atlas/tests -p 'test_*.py' -v
/tmp/safehub-checks/bin/python tools/run_hub_checks.py
```

전체 계약·부팅 stub·Windows 도구·호스트 C++와 Flutter의 정확한 명령은
[source-checks.yml](../.github/workflows/source-checks.yml)에 있습니다.
허브는 과거 실제 발행 스크립트가 섞여 있었으므로 임의의 `test_*.py`를 일괄 실행하지 않습니다.
선별한 assertion 스크립트만 연결 차단 runner로 실행합니다.

Flutter 호스트는 README의 고정 SDK/host lock으로 검사합니다. 기본 제품 화면을 확인하려면:

```sh
python3 SW/safehub_scenario/tool/run_ui_preview.py --check-only
python3 SW/safehub_scenario/tool/run_ui_preview.py
```

시연·CSI 수집/학습 도구는 `--developer-tools`가 필요합니다. 실제 연결용 개발 빌드에서
이 옵션을 켜면 장치 시험 명령이 가능하므로 장비 조작 승인과 별도로 다룹니다.
이번 작업에서는 실제 서비스 제어·실행본 교체·모터 시험·펌웨어 플래시를 하지 않았습니다.
