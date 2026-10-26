"""Independent MQTT/USB process. Does not access camera, CSI or sign models."""

import argparse
from collections import deque
import logging
import os
from pathlib import Path
import re
import signal
import threading
import time

import paho.mqtt.client as mqtt
import serial

from controller import SUBSCRIPTIONS, CURTAIN_TOPIC, UnoController

LOG = logging.getLogger("safehub.uno")


def broker_from_camera_script(path, fallback):
    try:
        text = Path(path).read_text()
        match = re.search(
            r"^export MQTT_BROKER=['\"]?([A-Za-z0-9_.:-]+)['\"]?\s*$", text, re.M
        )
        return match[1] if match else fallback
    except OSError:
        return fallback


def select_uno_port(explicit=""):
    if explicit:
        candidates = [Path(explicit)]
    else:
        candidates = list(Path("/dev/serial/by-id").glob("usb-Arduino*0043*"))
    candidates = [
        path for path in candidates if path.exists() and "Arduino" in path.name
    ]
    if len(candidates) != 1:
        raise OSError(
            "Expected exactly one Arduino Uno USB by-id port; never open the ESP32 port"
        )
    return str(candidates[0])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default=os.getenv("UNO_PORT", ""))
    parser.add_argument("--broker", default=os.getenv("MQTT_BROKER", "127.0.0.1"))
    parser.add_argument("--broker-script", default="/data/safehub/run_camera.sh")
    args = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
    )
    controller = UnoController()
    recent_curtain_packets = deque(maxlen=128)
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id="safehub-uno-rpi4",
        clean_session=True,
    )
    client.reconnect_delay_set(min_delay=1, max_delay=15)

    def connected(client, userdata, flags, reason, properties):
        if reason.is_failure:
            LOG.warning("MQTT connection rejected: %s", reason)
            return
        for topic, qos in SUBSCRIPTIONS:
            client.subscribe(topic, qos=qos)
        LOG.info("Subscribed to existing actuator/aircon topics")

    def message(client, userdata, msg):
        if msg.topic == CURTAIN_TOPIC and msg.mid:
            key = (msg.mid, bytes(msg.payload))
            if msg.dup and key in recent_curtain_packets:
                return
            recent_curtain_packets.append(key)
        previous_fan = controller.fan_on
        accepted = controller.receive(msg.topic, msg.payload, msg.retain)
        if accepted and (
            not msg.topic.endswith("aircon/command")
            or previous_fan != controller.fan_on
        ):
            LOG.info("Command accepted topic=%s", msg.topic)
        elif controller.last_rejection:
            LOG.warning("Command ignored: %s", controller.last_rejection)

    client.on_connect, client.on_message = connected, message
    host = broker_from_camera_script(args.broker_script, args.broker)
    client.connect_async(host, int(os.getenv("MQTT_PORT", "1883")), keepalive=20)
    client.loop_start()
    port = None
    ready_at = reconnect_at = 0.0
    next_broker_check = 0.0
    line_buffer = b""
    verified = False
    probe_sent = False
    probe_acks = set()
    try:
        while not stop.wait(0.05):
            now = time.monotonic()
            if now >= next_broker_check:
                next_broker_check = now + 5
                updated = broker_from_camera_script(args.broker_script, args.broker)
                if updated != host:
                    client.disconnect()
                    client.loop_stop()
                    host = updated
                    client.connect_async(
                        host, int(os.getenv("MQTT_PORT", "1883")), keepalive=20
                    )
                    client.loop_start()
                    LOG.info("Broker address follows existing camera configuration")
            try:
                if port is None:
                    if now < reconnect_at:
                        continue
                    name = select_uno_port(args.port)
                    port = serial.Serial(
                        name, 9600, timeout=0, write_timeout=0.5, exclusive=True
                    )
                    controller.disconnected()
                    ready_at = now + 2.5  # opening Uno USB can reset the sketch
                    line_buffer = b""
                    verified, probe_sent = False, False
                    probe_acks.clear()
                    LOG.info("Uno USB open %s; waiting for sketch startup", name)
                waiting = port.in_waiting
                if waiting:
                    line_buffer = (line_buffer + port.read(min(waiting, 1024)))[-4096:]
                    while b"\n" in line_buffer:
                        line, line_buffer = line_buffer.split(b"\n", 1)
                        text = line.decode("utf-8", errors="replace").strip()
                        LOG.info("Uno: %s", text)
                        if probe_sent and text in {
                            "Command: F",
                            "Command: V",
                            "Command: L",
                        }:
                            probe_acks.add(text[-1])
                            if len(probe_acks) == 3 and not verified:
                                verified = True
                                LOG.info("Uno command handler verified by F/V/L echoes")
                if now >= ready_at and not probe_sent:
                    port.write(b"FVLs")
                    probe_sent = True
                if probe_sent and not verified and now > ready_at + 5:
                    raise OSError(
                        "Uno sketch did not acknowledge the provided F/V/L protocol"
                    )
                if verified:
                    controller.tick(port.write)
            except (OSError, serial.SerialException) as error:
                LOG.warning("USB unavailable; retrying independently: %s", error)
                if port is not None:
                    try:
                        port.close()
                    except OSError:
                        pass
                port = None
                controller.disconnected()
                reconnect_at = now + 3
    finally:
        client.disconnect()
        client.loop_stop()
        if port is not None:
            try:
                controller.shutdown(port.write)
            except (OSError, serial.SerialException):
                pass
            port.close()


if __name__ == "__main__":
    main()
