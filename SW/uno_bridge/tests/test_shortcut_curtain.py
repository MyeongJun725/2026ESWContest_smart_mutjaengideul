import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parents[2] / "rpi5_hub"))
from sign_shortcut.core.action_executor import ActionExecutor
from sign_shortcut.core.device_control_message import build_device_control_message
from sign_shortcut.core.shortcut_manager import SignShortcut


class CurtainShortcutTests(unittest.TestCase):
    def test_direction_stop_use_existing_keys_and_device_topic_template(self):
        executor = ActionExecutor()
        for action, expected in [("on", True), ("off", False), ("stop", False)]:
            result = executor.execute(
                SignShortcut("선택한 수어", "livingroom", "curtain", action)
            )
            command = build_device_control_message(result)
            self.assertEqual(
                command.topic, "safehub/control/livingroom/curtain/command"
            )
            self.assertEqual(
                json.loads(command.payload),
                dict(
                    source="sign_shortcut",
                    action="stop" if action == "stop" else "set_power",
                    power_on=expected,
                ),
            )
        self.assertFalse(executor.livingroom_aircon_power_on)

    def test_manual_curtain_state_is_baseline_for_next_sign_toggle(self):
        executor = ActionExecutor()
        executor.sync_livingroom_curtain_power(True)
        result = executor.execute(
            SignShortcut("선택한 수어", "livingroom", "curtain", "toggle")
        )
        self.assertFalse(result.power_on)


if __name__ == "__main__":
    unittest.main()
