# CSI 런타임 출처와 변경 범위

이 디렉터리는 2026-10-04 노트북 WifiSensing2-src에서 복사한 실행용 Python 코드입니다. LOCAL_SOURCE_MANIFEST.json의 파일은 원본 노트북 소스와 동일한 SHA-256을 갖습니다.

- 참조 프로젝트: https://github.com/Dongbang-Yeuijiguk/2025ESWContest_smart_3019
- 원 저작권: Copyright (c) 2025 Dongbang Yeuijiguk
- 라이선스: MIT, 전문은 LICENSE에 보존합니다.
- 원본 커밋과 파일별 해시: soom_upstream/manifest.json
- 현재 전처리: 52채널, db4 DWT, 표준화, PCA 1성분, FFT 저역 통과. 현재 모델 입력은 4초/240시점입니다.
- 사용자 정의 행동, 측정 회차별 평가 분리, 기록 관리, NumPy 추론은 노트북 앱에서 이어받습니다.
- 상위 bridge.py/stream.py와 Flutter 화면은 이번 통합을 위해 추가했습니다. 원본 파이프라인의 숫자와 모델 구조는 변경하지 않았습니다.

Python/PyTorch/NumPy/SciPy/scikit-learn/PyWavelets/pandas/pyserial 등의 라이선스는 THIRD_PARTY_NOTICES.txt를 참고하세요. 개인 측정 기록·모델·Wi-Fi 설정은 이 소스에 포함하지 않습니다.
