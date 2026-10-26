"""Use the team's existing shortcut controller and absolute-power MQTT schema."""

import logging
import json
from collections import deque
import os
from pathlib import Path
import signal
import sys
import threading

# Deployment places SW/rpi5_hub alongside this entrypoint.
sys.path.insert(0, str(Path(__file__).parent / "hub"))
from main import build_application
from mqtt_receiver import SIGN_TRANSLATION_TOPIC, SHORTCUT_COMMAND_TOPIC, on_message
from sign_shortcut.core.action_executor import ActionResult
from sign_shortcut.core.device_control_message import build_device_control_message


def main():
    logging.basicConfig(level=logging.INFO)
    application = build_application()
    # An explicit first-run default; respect subsequent UI shortcut changes.
    if not application.config.shortcut_store_path.exists():
        application.shortcut_manager.register(
            "에어컨", "livingroom", "aircon", "toggle"
        )
        application.shortcut_store.save(application.shortcut_manager.get_all())
    stopped = threading.Event()
    recent_sign_packets = deque(maxlen=128)
    signal.signal(signal.SIGTERM, lambda *_: stopped.set())
    signal.signal(signal.SIGINT, lambda *_: stopped.set())

    def connected(client, userdata, flags, reason, properties):
        if reason.is_failure:
            return
        client.subscribe(SIGN_TRANSLATION_TOPIC, qos=1)
        client.subscribe(SHORTCUT_COMMAND_TOPIC, qos=1)
        client.subscribe("safehub/control/livingroom/aircon/command", qos=1)
        print("Existing sign shortcut topics connected", flush=True)

    def message(client, userdata, msg):
        if msg.retain or len(msg.payload) > 4096:
            return
        if msg.topic == SIGN_TRANSLATION_TOPIC and msg.mid:
            key = (msg.mid, bytes(msg.payload))
            if msg.dup and key in recent_sign_packets:
                return
            recent_sign_packets.append(key)
        if msg.topic == "safehub/control/livingroom/aircon/command":
            try:
                data = json.loads(msg.payload)
                if not isinstance(data, dict):
                    return
                if (
                    data.get("source") in {"sign_shortcut", "manual_test"}
                    and data.get("action") == "set_power"
                ):
                    application.action_executor.sync_livingroom_aircon_power(
                        data["power_on"]
                    )
            except (ValueError, KeyError, TypeError):
                logging.warning("Invalid absolute power state ignored")
            return
        on_message(client, userdata, msg)

    application.client.on_connect = connected
    application.client.on_message = message
    application.client.reconnect_delay_set(min_delay=1, max_delay=15)
    application.client.connect_async(
        application.config.broker_host, application.config.broker_port, 20
    )
    application.client.loop_start()
    try:
        # Absolute-state refresh recovers a restarted Uno adapter without
        # retained motor commands or adding MQTT fields/topics.
        while not stopped.wait(5):
            if not application.client.is_connected():
                continue
            state = application.action_executor.livingroom_aircon_power_on
            result = ActionResult(
                True,
                "livingroom",
                "aircon",
                "toggle",
                state,
                "Hub logical command state",
            )
            try:
                application.device_control_publisher.publish(
                    build_device_control_message(result)
                )
            except RuntimeError:
                logging.warning("Power-state refresh waits for MQTT reconnection")
    finally:
        application.client.disconnect()
        application.client.loop_stop()


if __name__ == "__main__":
    main()
