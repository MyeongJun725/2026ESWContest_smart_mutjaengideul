import unittest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from classifier import FireTextClassifier
class Model:
    def predict(self, text, k=1): return ['__label__FIRE'], [0.99]
class ScopeTests(unittest.TestCase):
    def test_clause_scope(self):
        classifier = FireTextClassifier(Model())
        for text, expected in [
            ('훈련이 아닙니다. 실제 화재가 발생했습니다. 즉시 대피하세요.', True),
            ('훈련은 취소되었습니다. 실제 화재가 발생했습니다.', True),
            ('화재가 발생했습니다. 엘리베이터를 사용하지 마세요.', True),
            ('화재가 발생하는 훈련입니다.', False),
            ('화재가 발생하지 않았습니다.', False),
            ('화재 예방 안내입니다.', False)]:
            with self.subTest(text=text): self.assertEqual(classifier.classify(text)['hazard'], expected)
