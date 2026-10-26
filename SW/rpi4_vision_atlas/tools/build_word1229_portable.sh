#!/usr/bin/env bash
# Local cross-build only. No SSH, device writes, service changes or installation.
# Based on the deployed sign_async_publish_rpi4_v1/build_portable.sh.
set -euo pipefail
repo=$(cd "$(dirname "$0")/../../.." && pwd)
: "${CROSS_ROOT:?Extracted GCC 13 cross toolchain and glibc 2.39 development sysroot}"
: "${TARGET_ROOT:?Read-only collection of the actual Pi4 runtime libraries}"
: "${HEADERS_ROOT:?Pinned opencv-4.9.0, ort, paho.mqtt.c-1.3.13 and generated headers}"
out="${OUT_DIR:-$repo/build/word1229-portable}"
mkdir -p "$out"
export LD_LIBRARY_PATH="$CROSS_ROOT/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cxx="$CROSS_ROOT/usr/bin/aarch64-linux-gnu-g++-13"
case "$("$cxx" -dumpmachine)" in aarch64*) ;; *) echo 'Expected AArch64 compiler' >&2; exit 1;; esac
sign="$repo/SW/rpi4_sign_cpp"
vision="$repo/SW/rpi4_vision_atlas/photo_pipeline"
lib="$TARGET_ROOT/usr/lib"
vision_lib="$TARGET_ROOT/data/safehub/lib"
# TARGET_ROOT must already have linker aliases to the collected device files;
# do not accidentally select Ubuntu's libstdc++/libc from the development sysroot.
for name in libstdc++.so libgcc_s.so libc.so libm.so libpaho-mqtt3c.so.1; do
  test -f "$lib/$name" || { echo "Missing device linker alias: $lib/$name" >&2; exit 1; }
done
sources=(active_targets c4_gate feature_v3 hand_input knn onehand_classifier
  runtime_data sign_classifier sign_runtime temporal_resample twohand_classifier vision_frame_hands)
sign_sources=()
for source in "${sources[@]}"; do sign_sources+=("$sign/src/$source.cpp"); done
"$cxx" --sysroot="$CROSS_ROOT" -std=c++17 -O2 -ffp-contract=off -pthread -DVISION_RAW_ONLY \
  -I"$sign/include" -I"$vision" -I"$HEADERS_ROOT/generated" \
  -I"$HEADERS_ROOT/opencv-4.9.0/modules/core/include" \
  -I"$HEADERS_ROOT/opencv-4.9.0/modules/imgproc/include" \
  -I"$HEADERS_ROOT/ort" -I"$HEADERS_ROOT/paho.mqtt.c-1.3.13/src" \
  "$vision/vision_stream_sign_decoupled.cpp" "$vision/live_sign_session.cpp" \
  "$vision/raw_tcp_streamer.cpp" "$vision/mqtt_translation_publisher.cpp" "${sign_sources[@]}" \
  -L"$lib" -L"$vision_lib" -Wl,-rpath-link,"$lib" -Wl,-rpath-link,"$vision_lib" \
  -Wl,-Map,"$out/link.map" \
  -l:libonnxruntime.so.1 -l:libopencv_imgproc.so.409 -l:libopencv_core.so.409 \
  -l:libpaho-mqtt3c.so.1 -l:ld-linux-aarch64.so.1 -o "$out/vision_word1229_candidate"
sha256sum "$out/vision_word1229_candidate" > "$out/SHA256SUMS"
readelf -h -l -d -V "$out/vision_word1229_candidate" > "$out/elf-report.txt"
printf '%s\n' 'Candidate only. Verify ABI against target collection; no device execution or installation performed.' > "$out/NOT_FOR_INSTALL.txt"
