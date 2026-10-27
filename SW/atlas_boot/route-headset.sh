#!/bin/sh
set -eu
sink=alsa_output.usb-GeneralPlus_USB_Audio_Device-00.analog-stereo
ready=false
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if pactl list short sinks 2>/dev/null | grep -Fq "$sink"; then
        ready=true
        break
    fi
    sleep 0.5
done
# Keep other outputs available when the selected headset is not connected.
if [ "$ready" != true ]; then
    logger -t safehub-audio 'Preferred USB headset not present; routing unchanged'
    exit 0
fi
pactl set-default-sink "$sink"
pactl set-sink-mute "$sink" 0
# Disable HDMI audio profiles only. This does not change video or mic capture.
pactl list short cards | while read -r index name rest; do
    case "$name" in
        alsa_card.platform-*hdmi*) pactl set-card-profile "$name" off ;;
    esac
done
pactl list short sink-inputs | while read -r index rest; do
    pactl move-sink-input "$index" "$sink" || true
done
