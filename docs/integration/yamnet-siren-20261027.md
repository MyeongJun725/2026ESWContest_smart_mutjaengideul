# Siren integration check — 2026-10-27

Pi5 YAMNet and shared STT microphone are active. UI 1.5.4 preserves the dashboard layout and the PR11 base. Backend policy `siren-family-v2` is installed. No MQTT topic or payload changes.

Fixed omitted Police car, Ambulance and Fire engine/fire truck siren classes in the backend, Dart input service and scenario flow. Candidate selection now compares all qualifying alarms before the household-alert margin. Thresholds and temporal confirmation remain unchanged. Sound-origin warnings request emergency confirmation without asserting a fire or location.

Verification: 12 Python policy/PCM/tap tests pass. Local full discovery cannot import the STT compatibility test because FastAPI is absent; this is not counted as a pass. Flutter sound/scenario/control/overlay regression group: 24 pass. Pi5 inference about 4–7 ms and fresh shared PCM were observed after deployment.

Real-model offline fixtures are not live microphone tests. Existing quantized model detected one of two ESC sirens and did not alert on clock/vacuum; the CC0 school-fire-alarm fixture was missed. Official Google full-float YAMNet was compared offline only: no policy events on these five fixtures, about 10 ms median; not deployed. These small fixtures are not an accuracy benchmark.

Known live phone replay after installation still produced mainly Music with alarm scores near zero and no event. Therefore target siren detection is NOT validated or resolved. No threshold was lowered merely to make this clip trigger. No actuator success is claimed; Uno had been unplugged. A labeled recording of the actual target alarm is needed for an additional task-specific classifier or calibrated acoustic detector.

Evidence: local output/yamnet-siren-20261027/status.json; remote /data/safehub-yamnet/siren-v2-stage/live-replay-20261027.json and offline reports. Only state telemetry was saved from the phone replay, no raw microphone audio.

Backend backup: /data/safehub-yamnet/backups/before-siren-v2-20261027-201824. UI backup: /data/safehub-pr7/releases/pr11-20261027/before-20261027-202003. UI package SHA256: a64c218f4bf37191f9f232f22b4a50e0a99237ac270130dfc597b501f0f4906e.

Sources: https://android.googlesource.com/platform/external/tensorflow/+/main/tensorflow/lite/g3doc/examples/audio_classification/overview.md ; https://www.kaggle.com/models/google/yamnet/tfLite/tflite/1 ; CC0 fixture https://bigsoundbank.com/fire-alarm-communities-1-s0268.html (Denis Chardonnet). Audio fixtures remain outside Git.

## Target reference extension

User labeled the supplied YouTube video's 0–12 seconds as siren-only. Download succeeded after fixing the local download tool. The original quantized model produced no alert on its first 20 seconds offline. Original model weights and the fastText service are unchanged.

A frozen Google YAMNet full-float embedding extractor plus a small reference matcher was added as an optional independent trigger. Training uses 0–8s (15 windows), same-recording temporal validation 8–12s (7 windows, 4 matches and one two-window-confirmed event). This is target-sound adaptation, not retraining the original 521-way model. Similarity is not a risk probability. Target cosine threshold 0.8 and negative prototype separation 0.17336455; two of three observed windows required, stream gaps clear confirmation and quiet re-arms the latch.

Twenty-one negative source files (music, speech, clock alarm, vacuum, door knock, clapping, washing machine and car horn) produced no target events in offline temporal evaluation. Some are training negatives, others held out by file; these small checks do not establish broad real-world false-alarm rates. No microphone negative trial has been completed.

During the user's phone replay the Pi5 emitted actual target-reference Siren events, including similarity 0.86749 with two confirmations. User confirmed the warning dialog appeared. This is one actual replay success, not a general siren recognition accuracy claim. Additional processing about 15–20 ms combined was observed. Actuator movement was not independently verified.

Optional target flags are configured on safehub-yamnet.service. Backend backup /data/safehub-yamnet/backups/before-target-20261027-203648 contains server.py, detection.py and the prior unit. Restore those files to their original paths, run systemctl daemon-reload then restart safehub-yamnet to disable the extension; retain the new assets for review. It uses the existing microphone tap and existing warning/actuation route; it opens no extra capture device and changes no MQTT schema.

Full embedding model SHA256: 141fba1cdaae842c816f28edc4937e8b4f0af4c8df21862ccc6b52dc567993c3. Reference SHA256: 9532bf2fb1eb398464a78d7668d23d8e46c6fb8d2210d593da106a13eca0d7eb. Reference and audio remain local, outside Git. Dataset/source/license manifest and reports: output/yamnet-siren-20261027/training. Main source: https://youtu.be/fWiV6kJmzLk ; negative examples https://librosa.org/doc/main/recordings.html and https://github.com/karolpiczak/ESC-50 . Preserve each recording's licensing metadata before any future redistribution.

## Additional emergency bell

User requested https://youtu.be/muDWcZltS9w (비상벨 소리 10분재생). Downloaded audio first 30 seconds converted to mono PCM16/16k; original 521-way model emitted no policy event in an offline run. Added a separate positive centroid from 0–10s, leaving previous siren centroid/threshold/margin unchanged. Same-source temporal validation 20–30s: 18 of 19 windows matched. Do not describe that as independent recognition accuracy.

New reference cosine threshold 0.83265197, separation margin 0.05, with the existing two-of-three confirmation and gap/quiet handling. Both reference vectors share one embedding inference; no second microphone or duplicate model inference per reference. Offline temporal checks: both target clips trigger, all 21 negative source files produce no target events. Four synthetic reference-format, identity, negative and reset/gap tests pass. Test sources include training negatives; file holdout is not full source/room/person generalization validation.

Live user phone replay emitted emergency-bell-muDWcZltS9w reference events (similarity 0.87496, two confirmations); captured native UI shows the recent alarm warning. Popup timing and physical motors were not independently captured. Typical combined processing around 15–21 ms observed.

Reference /data/safehub-yamnet/models/target-siren-bell-20261027.npz SHA256 4b9ec8c93cd0dc7e5acab2af978b83b5022c6d9fd72ac640238738294d54dce9. Previous single-reference file preserved. Backup /data/safehub-yamnet/backups/before-bell-20261027-204755 contains old target_siren.py, unit, and reference. Restore the prior target_siren.py and unit, daemon-reload and restart safehub-yamnet to roll back. Source and audio provenance/reports are retained locally in output/yamnet-siren-20261027; audio/reference not added to Git. No native UI rebuild or MQTT change was needed.
