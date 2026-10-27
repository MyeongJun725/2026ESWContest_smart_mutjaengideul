from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parents[1]))
from classifier import FireTextClassifier, summarize_context


class AlwaysFire:
    def predict(self, text, k=1):
        return (["__label__FIRE"], [0.999])


class ClassifierTests(unittest.TestCase):
    def setUp(self):
        self.classifier = FireTextClassifier(AlwaysFire())

    def test_negated_fire_is_not_an_alarm_even_with_high_model_score(self):
        for text in [
            "화재가 발생하지 않았습니다.",
            "화재는 없습니다.",
            "불이 나지 않았습니다.",
            "대피하지 않아도 됩니다.",
        ]:
            self.assertFalse(self.classifier.classify(text)["hazard"], text)

    def test_drill_and_prevention_are_not_real_alarm(self):
        for text in [
            "화재 대피 훈련입니다.",
            "화재 예방 안내입니다.",
            "화재 시연 테스트입니다.",
        ]:
            self.assertFalse(self.classifier.classify(text)["hazard"], text)

    def test_explicit_announcements_do_not_wait_for_audio_crosscheck(self):
        for text in [
            "화재가 발생했습니다. 신속히 대피해 주세요.",
            "불이 났습니다.",
            "비상입니다. 대피하세요.",
        ]:
            self.assertTrue(self.classifier.classify(text)["hazard"], text)

    def test_classifier_score_alone_never_activates_alarm(self):
        self.assertFalse(
            self.classifier.classify("오늘 저녁에 무엇을 먹을까요?")["hazard"]
        )

    def test_existing_incident_is_not_cancelled_by_new_negative_sentence(self):
        reply = summarize_context(
            {
                "selected_context": {
                    "workflow": {"scenario": "broadcast"},
                    "recent_dialogue": ["화재는 없습니다."],
                }
            },
            self.classifier,
        )
        self.assertIn("위험 안내방송", reply)
        self.assertLessEqual(len(reply), 90)

    def test_unknown_presence_does_not_become_unconscious_or_away(self):
        reply = summarize_context(
            {
                "selected_context": {
                    "workflow": {"scenario": "assistance"},
                    "sensor": "움직임 없음",
                }
            },
            self.classifier,
        )
        self.assertIn("미확인", reply)
        self.assertLessEqual(len(reply), 90)


if __name__ == "__main__":
    unittest.main()
