#!/bin/sh
# Read-only inventory: no services, camera, MQTT, configuration or firmware writes.
# Output contains hashes and paths only; keep it outside the public repository.
set -eu
role=${1:-}
case "$role" in pi4|pi5) ;; *) echo 'Expected pi4 or pi5' >&2; exit 2 ;; esac
printf 'SAFEHUB_INVENTORY_V1\t%s\n' "$role"
printf 'observed_utc\t%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf 'architecture\t%s\n' "$(uname -m)"
hash_file() {
    [ -f "$2" ] || return 0
    result=$(sha256sum "$2" 2>/dev/null) || return 0
    printf '%s\t%s\t%s\n' "$1" "${result%% *}" "$2"
}
for entry in /proc/[0-9]*/comm; do
    [ -r "$entry" ] || continue
    IFS= read -r name < "$entry" || continue
    case "$name" in vision*|safehub_app|flutter*|python*) ;; *) continue ;; esac
    process=${entry%/comm}
    hash_file process-exe "$process/exe"
    target=$(readlink "$process/exe" 2>/dev/null) || target=unknown
    printf 'process-path\t%s\t%s\n' "$process" "$target"
    # Python code paths only; never print complete command lines or env values.
    if [ -r "$process/cmdline" ]; then
        tr '\000' '\n' < "$process/cmdline" | while IFS= read -r arg; do
            case "$arg" in /data/*.py|/opt/*.py) hash_file process-source "$arg" ;; esac
        done
    fi
done
if [ "$role" = pi4 ]; then
    roots='/data/safehub /data/safehub-uno/app'
else
    roots='/opt/safehub-system /opt/safehub-stt /opt/safehub-tts /opt/safehub-csi /data/safehub-sign-control/app /data/safehub/fasttext/app /data/safehub-yamnet/app'
fi
for root in $roots; do
    [ -d "$root" ] || continue
    find "$root" \( -name venv -o -name python -o -name packages -o -name backups -o -name releases -o -name .git -o -name __pycache__ \) -prune -o \
        -type f \( -name '*.py' -o -name '*.sh' -o -name '*.cpp' -o -name '*.hpp' -o -name '*.dart' -o -name '*.service' \) -print |
        while IFS= read -r path; do hash_file installed-source "$path"; done
done
if [ "$role" = pi4 ]; then
    for path in /data/safehub/active_targets_v4.bin /data/safehub/models/palm_detection_mediapipe_2023feb.onnx /data/safehub/models/handpose_estimation_mediapipe_2023feb.onnx; do
        hash_file external-model "$path"
    done
else
    for path in /data/safehub/fasttext/fire_screen_model.bin /data/safehub-yamnet/models/yamnet.tflite /data/safehub-yamnet/models/target-siren-bell-20261027.npz; do
        hash_file external-model "$path"
    done
fi
# No source contents, settings, recordings, credentials, model bytes or archives.
printf 'inventory-complete\t%s\n' "$role"
