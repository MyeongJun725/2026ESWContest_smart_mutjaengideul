# Device integration review · 2026-10-28

This change follows PR #11 and targets `develop`. It is not a final deployment approval.

## Changes

- Emergency events can play one fixed offline announcement per incident. Repeats and acknowledgement use a serialized audio lifecycle. Connection settings expose the TTS endpoint and its health check.
- ATLAS audio uses bounded GStreamer playback when its native tools are available. A boot service prefers the connected USB headset without changing microphone selection. Online synthesis still requires network access.
- Optional siren references supplement frozen YAMNet embeddings; similarity is not a calibrated probability. Reference/model files and downloaded source recordings are not included.
- CSI monitoring focuses on fall events, rejects synthetic/stale predictions, and requires fresh stable predictions before raising an incident. PC training and Pi collection/preprocessing/inference remain separate. Existing recording files are preserved.
- Pi4 tracking preserves successful current-frame observations during recovery, bounds inference work, and checks duplicate hands. A narrow static-support-hand reference comparison supplements the existing classifier.
- Optional hand landmarks are rendered on the corresponding inference frame, without modifying classifier input. Brightness normalization is disabled by default and was disabled in the device wrapper at handoff.
- MQTT broker configuration, topics and external JSON contracts are unchanged.

## Checks

| Check | Result | Scope |
|---|---|---|
| Flutter full suite, Windows host / Flutter 3.27.4 | 285 passed, 1 skipped | Widgets, state, fake services and loopback transport; not device accuracy |
| Flutter analyze | No errors/warnings; 4 existing deprecation infos | Staged current sources |
| C++ CTest | 24 passed | Host regressions, fixtures and scripted model behavior |
| CSI fall policy | 10 passed | Synthetic policy inputs |
| YAMNet alarm policy / target reference | 7 / 4 passed | Policy inputs and fake interpreter; isolated Pi5 source copy |
| Boot ordering | 4 passed | Fake systemctl in isolated Pi5 source copy |
| TTS ASGI / STT optional-tap compatibility | 8 / 2 passed | Fake synthesis/recognizer; isolated test dependencies |
| Asset audit regression | 1 passed | File and directory asset declarations |
| Source audit and whitespace check | Passed | No missing imports/assets; private artifacts excluded |

The updated FastAPI test client requires `httpx2`; the test requirements pin it alongside the existing `httpx` dependency. No running service was changed for these source checks. GitHub CI uses the repository's pinned Flutter version and must be reviewed separately after publication.

## Remaining field validation

- WORD1229 was observed once as ID 15 with 38 paired observations and an MQTT result, but other attempts still produced one-hand outputs. This is not a measured recognition rate or proof of reliable recovery.
- No trained fall-labelled model is installed on Pi5 at this handoff. End-to-end real CSI fall detection and false-alarm rates remain unverified.
- Siren playback previously produced an alert with the selected demonstration sounds. Generalization to other alarms, rooms and noise levels is unmeasured.
- Disaster API polling is present; the main dashboard still lacks a dedicated persistent disaster card.
- Existing model/reference files, credentials, user recordings and deployment binaries are not part of this PR. Use the component deployment notes and back up current device files before building or installing replacements.
