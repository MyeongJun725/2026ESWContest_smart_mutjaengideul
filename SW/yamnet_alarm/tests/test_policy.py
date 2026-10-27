from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parents[1]))
from detection import AlarmPolicy


class PolicyTests(unittest.TestCase):
    def test_specific_alarm_requires_two_observed_windows(self):
        policy = AlarmPolicy()
        self.assertIsNone(policy.update({"Fire alarm": 0.8}, 1.0))
        self.assertEqual(policy.update({"Fire alarm": 0.8}, 1.5)["label"], "Fire alarm")
        self.assertIsNone(policy.update({"Fire alarm": 0.8}, 2.0))

    def test_one_spike_and_common_household_alerts_do_not_trigger(self):
        policy = AlarmPolicy()
        self.assertIsNone(policy.update({"Siren": 0.9}, 1.0))
        for at in [1.5, 2.0, 2.5, 3.0]:
            self.assertIsNone(
                policy.update({"Alarm clock": 0.95, "Fire alarm": 0.4}, at)
            )

    def test_audio_gap_breaks_confirmation(self):
        policy = AlarmPolicy()
        self.assertIsNone(policy.update({"Siren": 0.9}, 1.0))
        self.assertIsNone(policy.update({"Siren": 0.9}, 4.0))

    def test_same_alarm_latches_until_two_seconds_quiet(self):
        policy = AlarmPolicy()
        policy.update({"Smoke detector, smoke alarm": 0.8}, 1.0)
        self.assertIsNotNone(policy.update({"Smoke detector, smoke alarm": 0.8}, 1.5))
        for at in [2.0, 2.5, 3.0, 3.5, 4.0]:
            self.assertIsNone(policy.update({}, at))
        self.assertIsNone(policy.update({"Siren": 0.9}, 4.5))
        self.assertIsNotNone(policy.update({"Siren": 0.9}, 5.0))


if __name__ == "__main__":
    unittest.main()
