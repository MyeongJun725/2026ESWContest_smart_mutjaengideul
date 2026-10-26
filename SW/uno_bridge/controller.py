"""Existing SafeHub MQTT commands -> existing Uno single-byte commands."""

from collections import OrderedDict
import json
import math
import threading
import time

LED_TOPIC = "safehub/actuator/led/command"
SHAKER_TOPIC = "safehub/actuator/bedshaker/command"
AIRCON_TOPIC = "safehub/control/livingroom/aircon/command"
SUBSCRIPTIONS = ((LED_TOPIC, 1), (SHAKER_TOPIC, 1), (AIRCON_TOPIC, 1))


class UnoController:
    def __init__(self, monotonic=time.monotonic, wall=time.time):
        self.monotonic, self.wall = monotonic, wall
        self.lock = threading.RLock()
        self.fan_on = False
        self.led_mode = "off"
        self.led_until = self.shaker_until = self.blink_started = 0.0
        self.seen = OrderedDict()
        self.wire = None
        self.last_rejection = ""

    def receive(self, topic, payload, retained=False):
        with self.lock:
            self.last_rejection = ""
            try:
                if retained or len(payload) > 4096:
                    raise ValueError("retained/oversize command")
                data = json.loads(payload)
                if not isinstance(data, dict):
                    raise ValueError("command must be an object")
                if topic == AIRCON_TOPIC:
                    # Existing payload has no ID or timestamp. Absolute state
                    # is idempotent; never interpret it as another toggle.
                    if (
                        data.get("source") not in {"sign_shortcut", "manual_test"}
                        or data.get("action") != "set_power"
                        or type(data.get("power_on")) is not bool
                    ):
                        raise ValueError("invalid existing aircon command")
                    self.fan_on = data["power_on"]
                    return True
                if topic not in (LED_TOPIC, SHAKER_TOPIC):
                    raise ValueError("unsupported topic; curtain control is disabled")
                device = "led" if topic == LED_TOPIC else "bedshaker"
                if (
                    data.get("device") != "rpi5_hub"
                    or data.get("event") != f"{device}_command"
                ):
                    raise ValueError("wrong command device/event")
                stamp = data.get("timestamp")
                if type(stamp) is not int or not -5 <= self.wall() - stamp <= 30:
                    raise ValueError("stale/future/missing timestamp")
                message_id = data.get("message_id")
                if not isinstance(message_id, str) or not 1 <= len(message_id) <= 128:
                    raise ValueError("missing message_id")
                action = data.get("action")
                if action not in (
                    {"on", "off", "blink"} if device == "led" else {"on", "off"}
                ):
                    raise ValueError("unsupported action")
                duration = data.get("duration_sec", 0 if action == "off" else 10)
                if device == "bedshaker" and (
                    type(duration) is not int
                    or not 0 <= duration <= 10
                    or (action == "on" and duration < 1)
                ):
                    raise ValueError("invalid duration_sec")
                now = self.monotonic()
                while self.seen and next(iter(self.seen.values())) < now - 300:
                    self.seen.popitem(last=False)
                key = (topic, message_id)
                if key in self.seen:
                    return False
                self.seen[key] = now
                while len(self.seen) > 256:
                    self.seen.popitem(last=False)
                if device == "led":
                    self.led_mode = action
                    self.blink_started = now
                    self.led_until = now + 10 if action != "off" else now
                else:
                    self.shaker_until = now + duration if action == "on" else now
                return True
            except (ValueError, TypeError, UnicodeDecodeError) as error:
                self.last_rejection = str(error)
                return False

    def disconnected(self):
        with self.lock:
            self.wire = None

    def tick(self, write):
        with self.lock:
            now = self.monotonic()
            led = now < self.led_until and self.led_mode != "off"
            if led and self.led_mode == "blink":
                led = math.floor((now - self.blink_started) / 0.25) % 2 == 0
            desired = (self.fan_on, now < self.shaker_until, led)
            previous = self.wire
            commands = b"".join(
                (on if state else off)
                for index, (state, on, off) in enumerate(
                    zip(desired, (b"f", b"v", b"l"), (b"F", b"V", b"L"))
                )
                if previous is None or previous[index] != state
            )
            if commands:
                written = write(commands)
                if written is not None and written != len(commands):
                    raise OSError("Incomplete Uno serial write")
            # Only a successful write advances the sent state.
            self.wire = desired
            return commands

    def shutdown(self, write):
        with self.lock:
            self.fan_on = False
            self.led_until = self.shaker_until = 0
            self.tick(write)
