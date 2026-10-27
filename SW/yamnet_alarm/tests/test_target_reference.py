"""Synthetic reference/temporal regressions; not acoustic accuracy tests."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
sys.path.insert(0, str(Path(__file__).parents[1]))
from target_siren import TargetSiren


class FakeInterpreter:
    def __init__(self, **kwargs):
        self.vector = np.eye(1, 1024, 0, dtype=np.float32)
    def get_input_details(self):
        return [{'index': 0}]
    def resize_tensor_input(self, *args):
        pass
    def allocate_tensors(self):
        pass
    def get_output_details(self):
        return [{'index': 1, 'shape': np.array([1, 1024])}]
    def set_tensor(self, *args):
        pass
    def invoke(self):
        pass
    def get_tensor(self, index):
        return self.vector.copy()


class TargetReferenceTests(unittest.TestCase):
    def make_target(self, legacy=False):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        file = Path(folder.name) / 'reference.npz'
        vectors = np.eye(3, 1024, dtype=np.float32)
        data = dict(negative_prototypes=vectors[2:])
        if legacy:
            data.update(centroid=vectors[0], threshold=.8, margin=.1)
        else:
            data.update(centroids=vectors[:2], thresholds=np.array([.8, .85]),
                        margins=np.array([.1, .1]), reference_names=np.array(['old', 'bell']))
        np.savez(file, **data)
        with patch('target_siren.Interpreter', FakeInterpreter):
            return TargetSiren('unused-model', file)

    def test_both_references_trigger_and_keep_identity(self):
        for index, name in enumerate(['old', 'bell']):
            target = self.make_target()
            target.model.vector = np.eye(1, 1024, index, dtype=np.float32)
            self.assertIsNone(target.observe(np.zeros(15600, np.float32), 1)[0])
            event, _ = target.observe(np.zeros(15600, np.float32), 1.5)
            self.assertEqual(event['reference'], name)

    def test_negative_does_not_trigger(self):
        target = self.make_target()
        target.model.vector = np.eye(1, 1024, 2, dtype=np.float32)
        for now in [1, 1.5, 2]:
            event, state = target.observe(np.zeros(15600, np.float32), now)
            self.assertIsNone(event)
            self.assertFalse(state['matched'])

    def test_gap_and_reset_clear_confirmation(self):
        target = self.make_target()
        for now in [1, 3]:
            self.assertIsNone(target.observe(np.zeros(15600, np.float32), now)[0])
        target.reset()
        self.assertIsNone(target.observe(np.zeros(15600, np.float32), 3.5)[0])

    def test_legacy_reference_still_loads(self):
        target = self.make_target(legacy=True)
        self.assertEqual(target.centroids.shape, (1, 1024))
