"""Fall-only alert policy over fresh classifier outputs; no invented samples."""
import math
import time
import uuid

FALL_LABELS = frozenset(('낙상', '쓰러짐', '쓰러지다'))
NORMAL_LABELS = frozenset(('일상', '일상 동작', '정지', '걷기', '앉기', '서기'))


def fall_training_records(records):
    """Map selected copies to two labels; leave saved originals unchanged."""
    mapped = []
    for record in records:
        label = record['label']
        if label not in FALL_LABELS | NORMAL_LABELS:
            raise ValueError(f'{label}: 낙상 또는 일상 동작 기록만 선택하세요.')
        mapped.append(dict(record, label='낙상' if label in FALL_LABELS else '일상'))
    if {r['label'] for r in mapped} != {'낙상', '일상'}:
        raise ValueError('실제 낙상 기록과 일상 동작 기록을 함께 선택하세요.')
    return mapped


class FallDetector:
    def __init__(self, hold_seconds=.5, rearm_seconds=2., cooldown_seconds=10.):
        self.hold_seconds = hold_seconds
        self.rearm_seconds = rearm_seconds
        self.cooldown_seconds = cooldown_seconds
        self.model = None
        self.reset()

    def reset(self, model=None):
        self.model = model
        self.candidate_at = None
        self.candidate_count = 0
        self.normal_at = None
        self.last_input = None
        self.last_observed = None
        self.latched_at = None
        self.event = None
        self.status = 'warming' if self.eligible else 'model_required'

    @property
    def eligible(self):
        labels = set((self.model or {}).get('labels', ()))
        return bool(labels & FALL_LABELS) and bool(labels - FALL_LABELS)

    def unavailable(self):
        self.candidate_at = self.normal_at = None
        self.candidate_count = 0
        self.last_observed = None
        self.event = None
        self.status = 'signal_wait' if self.eligible else 'model_required'

    def observe(self, result, *, input_end, now, real=True, wall_time=None):
        if not self.eligible:
            self.status = 'model_required'
            return
        if not real or not math.isfinite(input_end) or not 0 <= now-input_end <= .75:
            self.unavailable()
            return
        # Repeated HTTP polls or repeated predictions of the same input never
        # count as further confirmation.
        if self.last_input is not None and input_end <= self.last_input:
            return
        if self.last_observed is not None and now-self.last_observed > 2.5:
            self.candidate_at = self.normal_at = None
            self.candidate_count = 0
        self.last_input, self.last_observed = input_end, now
        scores = result.get('scores', {})
        if (not isinstance(scores, dict) or not scores or
                any(not isinstance(v, (int, float)) or not math.isfinite(v) or not 0 <= v <= 1 for v in scores.values())):
            self.unavailable()
            return
        positive = max((scores.get(label, 0.) for label in FALL_LABELS), default=0.)
        negative = max((score for label, score in scores.items() if label not in FALL_LABELS), default=0.)
        threshold = float(self.model.get('score_threshold', .65))
        margin = float(self.model.get('score_margin', .15))
        is_fall = result.get('label') in FALL_LABELS and positive >= threshold and positive-negative >= margin
        normal = (result.get('label') in set(self.model.get('labels', ())) - FALL_LABELS
                  and negative >= threshold and negative-positive >= margin)
        if self.latched_at is not None:
            self.status = 'detected'
            if normal:
                if self.normal_at is None: self.normal_at = now
                if now-self.normal_at >= self.rearm_seconds and now-self.latched_at >= self.cooldown_seconds:
                    self.latched_at = self.event = self.normal_at = None
                    self.status = 'monitoring'
            else:
                self.normal_at = None
            return
        if is_fall:
            if self.candidate_at is None: self.candidate_at = now
            self.candidate_count += 1
            self.status = 'confirming'
            if self.candidate_count >= 2 and now-self.candidate_at >= self.hold_seconds:
                self.latched_at = now
                self.status = 'detected'
                self.event = {'message_id': 'csi-fall-'+uuid.uuid4().hex,
                    'device': 'csi_bedroom', 'event': 'fall_detected',
                    'confidence': positive, 'priority': 9,
                    'timestamp': int(time.time() if wall_time is None else wall_time)}
        else:
            self.candidate_at = None
            self.candidate_count = 0
            self.status = 'monitoring' if normal else 'uncertain'

    def snapshot(self):
        return {'status': self.status, 'eligible': self.eligible,
                'event': self.event, 'hold_seconds': self.hold_seconds,
                'rearm_seconds': self.rearm_seconds, 'cooldown_seconds': self.cooldown_seconds}
