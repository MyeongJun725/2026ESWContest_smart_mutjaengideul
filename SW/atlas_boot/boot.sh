#!/bin/sh
set -eu
# /data units are not visible when systemd first builds the boot transaction.
systemctl daemon-reload
systemctl --no-block start safehub-mqtt.service safehub-csi.service safehub-ui.service
# Resolve installed units through systemd after the /data mount and reload.
# This also respects an /etc override instead of assuming one unit-file path.
# External STT configurations need no local unit.
if [ "$(systemctl show --property=LoadState --value safehub-stt.service 2>/dev/null || true)" = loaded ]; then
    systemctl --no-block start safehub-stt.service
fi
