"""Optional few-shot siren reference matcher over frozen YAMNet embeddings.

Similarity is not a calibrated emergency probability. No audio is stored.
"""
import numpy as np
from ai_edge_litert.interpreter import Interpreter
from detection import AlarmPolicy


class TargetSiren:
    def __init__(self, model_path, reference_path):
        with np.load(reference_path, allow_pickle=False) as data:
            if 'centroids' in data:
                self.centroids = data['centroids'].astype(np.float32)
                self.thresholds = data['thresholds'].astype(np.float32)
                self.margins = data['margins'].astype(np.float32)
                self.names = data['reference_names'].tolist()
            else:
                self.centroids = data['centroid'].astype(np.float32)[None, :]
                self.thresholds = np.array([float(data['threshold'])])
                self.margins = np.array([float(data['margin'])])
                self.names = ['fire-siren-fWiV6kJmzLk']
            self.negatives = data['negative_prototypes'].astype(np.float32)
        count = len(self.centroids)
        if (self.centroids.shape != (count, 1024) or not 1 <= count <= 16
                or self.negatives.ndim != 2 or len(self.negatives) == 0
                or self.negatives.shape[1] != 1024
                or self.thresholds.shape != (count,) or self.margins.shape != (count,)
                or len(self.names) != count
                or not np.all((self.thresholds > 0) & (self.thresholds <= 1))
                or not np.all((self.margins > 0) & (self.margins <= 2))
                or not np.isfinite(self.centroids).all()
                or not np.isfinite(self.negatives).all()
                or not np.allclose(np.linalg.norm(self.centroids, axis=1), 1, atol=1e-4)):
            raise ValueError('Invalid target siren reference')
        self.model = Interpreter(model_path=model_path, num_threads=1)
        self.input_id = self.model.get_input_details()[0]['index']
        self.model.resize_tensor_input(self.input_id, [15600])
        self.model.allocate_tensors()
        outputs = self.model.get_output_details()
        self.output_id = next(x['index'] for x in outputs
                              if x['shape'].tolist() == [1, 1024])
        self.policy = AlarmPolicy(siren_threshold=float(self.thresholds.min()))

    def reset(self):
        self.policy.reset()

    def observe(self, waveform, now):
        self.model.set_tensor(self.input_id, waveform)
        self.model.invoke()
        embedding = self.model.get_tensor(self.output_id)[0]
        embedding /= max(float(np.linalg.norm(embedding)), 1e-9)
        similarities = self.centroids @ embedding
        separations = similarities - float(np.max(self.negatives @ embedding))
        valid = (np.isfinite(similarities) & np.isfinite(separations)
                 & (similarities >= self.thresholds) & (separations >= self.margins))
        matched = bool(valid.any())
        index = int(np.argmax(np.where(valid, similarities, -np.inf))
                    if matched else np.argmax(similarities))
        similarity = float(similarities[index])
        separation = float(separations[index])
        event = self.policy.update({'Siren': min(1.0, similarity) if matched else 0.0}, now)
        if event:
            event.update(detector='yamnet-target-reference-v2', separation=separation,
                         reference=self.names[index])
        return event, dict(similarity=round(similarity, 4),
                           separation=round(separation, 4), matched=matched,
                           reference=self.names[index],
                           threshold=float(self.thresholds[index]),
                           margin=float(self.margins[index]))
