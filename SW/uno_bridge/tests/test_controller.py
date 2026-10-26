import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parents[1]))
from controller import (
    AIRCON_TOPIC,
    CURTAIN_TOPIC,
    LED_TOPIC,
    SHAKER_TOPIC,
    UnoController,
)


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.now = 100.0
        self.controller = UnoController(lambda: self.now, lambda: 1000)
        self.writes = []

    def payload(self, device, action, identity="id", **extra):
        return json.dumps(
            dict(
                message_id=identity,
                device="rpi5_hub",
                event=device + "_command",
                action=action,
                timestamp=1000,
                **extra
            )
        ).encode()

    def tick(self):
        return self.controller.tick(self.writes.append)

    def test_alarm_blinks_and_expires_without_fan(self):
        self.assertTrue(
            self.controller.receive(LED_TOPIC, self.payload("led", "blink"))
        )
        self.assertTrue(
            self.controller.receive(
                SHAKER_TOPIC, self.payload("bedshaker", "on", duration_sec=2)
            )
        )
        self.assertEqual(self.tick(), b"Fvl")
        self.now += 0.25
        self.assertEqual(self.tick(), b"L")
        self.now += 0.25
        self.assertEqual(self.tick(), b"l")
        self.now = 102
        self.assertEqual(self.tick(), b"V")
        self.now = 111
        self.assertEqual(self.tick(), b"L")

    def test_alarm_ack_preserves_fan(self):
        fan = json.dumps(
            dict(source="sign_shortcut", action="set_power", power_on=True)
        ).encode()
        self.assertTrue(self.controller.receive(AIRCON_TOPIC, fan))
        self.controller.receive(LED_TOPIC, self.payload("led", "blink"))
        self.controller.receive(
            SHAKER_TOPIC, self.payload("bedshaker", "on", duration_sec=10)
        )
        self.assertEqual(self.tick(), b"fvl")
        self.controller.receive(LED_TOPIC, self.payload("led", "off", "clear-led"))
        self.controller.receive(
            SHAKER_TOPIC, self.payload("bedshaker", "off", "clear-vib", duration_sec=0)
        )
        self.assertEqual(self.tick(), b"VL")
        self.assertTrue(self.controller.fan_on)

    def test_absolute_fan_duplicate_never_toggles(self):
        message = json.dumps(
            dict(source="sign_shortcut", action="set_power", power_on=True)
        ).encode()
        self.controller.receive(AIRCON_TOPIC, message)
        self.tick()
        self.controller.receive(AIRCON_TOPIC, message)
        self.assertEqual(self.tick(), b"")

    def test_duplicate_does_not_extend_shaker(self):
        message = self.payload("bedshaker", "on", duration_sec=1)
        self.assertTrue(self.controller.receive(SHAKER_TOPIC, message))
        self.tick()
        self.now += 0.8
        self.assertFalse(self.controller.receive(SHAKER_TOPIC, message))
        self.now += 0.3
        self.assertEqual(self.tick(), b"V")

    def test_stale_retained_unknown_and_curtain_rejected(self):
        message = self.payload("led", "blink")
        self.assertFalse(self.controller.receive(LED_TOPIC, message, retained=True))
        stale = json.loads(message)
        stale["timestamp"] = 900
        self.assertFalse(self.controller.receive(LED_TOPIC, json.dumps(stale).encode()))
        for action in ["u", "j", "s", "x", "a"]:
            self.assertFalse(
                self.controller.receive(LED_TOPIC, self.payload("led", action))
            )
        self.assertFalse(
            self.controller.receive("safehub/control/curtain/command", message)
        )
        self.assertEqual(self.tick(), b"FVL")

    def test_bad_duration_does_not_consume_id(self):
        self.assertFalse(
            self.controller.receive(
                SHAKER_TOPIC, self.payload("bedshaker", "on", duration_sec=100)
            )
        )
        self.assertTrue(
            self.controller.receive(
                SHAKER_TOPIC, self.payload("bedshaker", "on", duration_sec=1)
            )
        )

    def test_reconnect_resends_only_current_not_expired_commands(self):
        self.controller.receive(
            SHAKER_TOPIC, self.payload("bedshaker", "on", duration_sec=1)
        )
        self.tick()
        self.controller.disconnected()
        self.now += 2
        self.assertEqual(self.tick(), b"FVL")

    def test_failed_write_does_not_advance_state(self):
        def broken(_):
            raise OSError("USB disconnected")

        with self.assertRaises(OSError):
            self.controller.tick(broken)
        self.assertEqual(self.tick(), b"FVL")

    def curtain(self, action="set_power", power_on=True):
        return self.controller.receive(
            CURTAIN_TOPIC,
            json.dumps(
                dict(source="manual_test", action=action, power_on=power_on)
            ).encode(),
        )

    def test_curtain_reverse_stops_then_waits_before_changing_direction(self):
        self.tick()
        self.assertTrue(self.curtain())
        self.assertEqual(self.tick(), b"u")
        self.now += 0.1
        self.curtain(power_on=False)
        self.assertEqual(self.tick(), b"s")
        self.now += 0.1
        self.assertEqual(self.tick(), b"")
        self.now += 0.16
        self.assertEqual(self.tick(), b"j")
        self.curtain(action="stop")
        self.assertEqual(self.tick(), b"s")

    def test_curtain_old_or_disconnected_request_is_not_replayed(self):
        self.tick()
        self.curtain()
        self.now += 3
        self.assertEqual(self.tick(), b"")
        self.curtain()
        self.controller.disconnected()
        self.assertEqual(self.tick(), b"FVL")

    def test_curtain_stop_does_not_turn_off_running_fan(self):
        self.controller.receive(
            AIRCON_TOPIC,
            json.dumps(
                dict(source="manual_test", action="set_power", power_on=True)
            ).encode(),
        )
        self.tick()
        self.curtain()
        self.tick()
        self.curtain(action="stop")
        self.assertEqual(self.tick(), b"s")
        self.assertTrue(self.controller.fan_on)

    def test_curtain_restart_waits_for_firmware_auto_stop_cooldown(self):
        self.tick()
        self.curtain()
        self.tick()
        self.now += 1.6
        self.curtain(power_on=False)
        self.assertEqual(self.tick(), b"")
        self.now += 0.16
        self.assertEqual(self.tick(), b"j")


if __name__ == "__main__":
    unittest.main()
