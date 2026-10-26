#!/usr/bin/env bash
# Compile only. This script never connects to, stops, or installs on a Pi.
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/../../.." && pwd)
vision_dir="$repo_dir/SW/rpi4_vision_atlas/photo_pipeline"
sign_dir="$repo_dir/SW/rpi4_sign_cpp"
: "${SDKTARGETSYSROOT:?Source the ATLAS ARM64 SDK environment first}"
: "${CXX:?Source the ATLAS ARM64 SDK environment first}"
: "${VISION_LIB_DIR:?Directory containing target OpenCV 4.9 and ONNX Runtime libraries}"
: "${PAHO_SDK_DIR:?Directory with target include/MQTTClient.h and lib/libpaho-mqtt3c.so}"
out_dir="${OUT_DIR:-$repo_dir/build/word1229-candidate}"
mkdir -p "$out_dir"
read -r -a compiler <<< "$CXX"
sources=(active_targets c4_gate feature_v3 hand_input knn onehand_classifier
    runtime_data sign_classifier sign_runtime temporal_resample twohand_classifier vision_frame_hands)
sign_sources=()
for source in "${sources[@]}"; do sign_sources+=("$sign_dir/src/$source.cpp"); done
"${compiler[@]}" -std=c++17 -O2 -ffp-contract=off -pthread -DVISION_RAW_ONLY \
    -I"$SDKTARGETSYSROOT/usr/include/opencv4" \
    -I"$SDKTARGETSYSROOT/usr/include/onnxruntime" \
    -I"$PAHO_SDK_DIR/include" -I"$sign_dir/include" -I"$vision_dir" \
    "$vision_dir/vision_stream_sign_decoupled.cpp" \
    "$vision_dir/live_sign_session.cpp" "$vision_dir/raw_tcp_streamer.cpp" \
    "$vision_dir/mqtt_translation_publisher.cpp" "${sign_sources[@]}" \
    -L"$VISION_LIB_DIR" -L"$PAHO_SDK_DIR/lib" \
    -Wl,-rpath-link,"$VISION_LIB_DIR" -Wl,-rpath-link,"$SDKTARGETSYSROOT/usr/lib" \
    -l:libonnxruntime.so.1 -l:libopencv_imgproc.so.409 -l:libopencv_core.so.409 \
    -lpaho-mqtt3c -o "$out_dir/vision_word1229_candidate"
git -C "$repo_dir" rev-parse HEAD > "$out_dir/base-commit.txt"
git -C "$repo_dir" diff --binary > "$out_dir/uncommitted-changes.patch"
find "$vision_dir" "$sign_dir/include" "$sign_dir/src" -type f \
    \( -name '*.cpp' -o -name '*.hpp' -o -name '*.inc' \) -print0 \
    | sort -z | xargs -0 sha256sum > "$out_dir/source-SHA256SUMS"
sha256sum "$out_dir/vision_word1229_candidate" > "$out_dir/SHA256SUMS"
printf '%s\n' 'SOURCE REVIEW CANDIDATE ONLY. ARM build and camera validation are not established by host tests.' > "$out_dir/NOT_FOR_INSTALL.txt"
printf 'Built candidate in %s. No installation or camera execution performed.\n' "$out_dir"
