import unittest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from classifier import FireTextClassifier
class Model:
    def predict(self, text, k=1):
        assert '\n' not in text and '\r' not in text, 'fastText requires a single line'
        return ['__label__FIRE'], [0.99]
class ScopeTests(unittest.TestCase):
    def test_clause_scope(self):
        classifier = FireTextClassifier(Model())
        import json
        corpus = Path(__file__).resolve().parents[3] / 'SW/safehub_scenario/test/fixtures/broadcast_cases.json'
        for case in json.loads(corpus.read_text()):
            text, expected = case['text'], case['hazard']

            with self.subTest(text=text): self.assertEqual(classifier.classify(text)['hazard'], expected)

    def test_model_input_is_single_line_but_rule_text_keeps_line_breaks(self):
        result = FireTextClassifier(Model()).classify('훈련이 아닙니다\r\n실제 화재가 발생했습니다')
        self.assertIn('\n', result['text'])
        self.assertTrue(result['hazard'])
