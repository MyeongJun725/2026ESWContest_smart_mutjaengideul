"""Temporal alarm-sound policy; scores are not calibrated fire probabilities."""

from collections import deque

SPECIFIC = {"Fire alarm", "Smoke detector, smoke alarm", "Civil defense siren"}
DISTRACTORS = {
    "Alarm clock",
    "Ringtone",
    "Telephone bell ringing",
    "Doorbell",
    "Buzzer",
}


class AlarmPolicy:
    def __init__(self, specific_threshold=0.35, siren_threshold=0.65):
        self.specific_threshold = specific_threshold
        self.siren_threshold = siren_threshold
        self.history = deque(maxlen=3)
        self.last_at = None
        self.latched = False
        self.quiet_since = None

    def reset(self):
        self.history.clear()
        self.last_at = self.quiet_since = None
        self.latched = False

    def update(self, scores, now):
        if self.last_at is not None and now - self.last_at > 1.1:
            self.reset()
        self.last_at = now
        label = max(SPECIFIC, key=lambda x: scores.get(x, 0.0))
        score = scores.get(label, 0.0)
        specific = score >= self.specific_threshold
        if not specific:
            label, score = "Siren", scores.get("Siren", 0.0)
        distractor = max((scores.get(x, 0.0) for x in DISTRACTORS), default=0.0)
        positive = bool(
            (specific or score >= self.siren_threshold) and score >= distractor + 0.05
        )
        self.history.append(positive)
        if not positive:
            self.quiet_since = now if self.quiet_since is None else self.quiet_since
            if now - self.quiet_since >= 2:
                self.latched = False
            return None
        self.quiet_since = None
        if not self.latched and len(self.history) >= 2 and sum(self.history) >= 2:
            self.latched = True
            return dict(
                label=label, score=float(score), confirmations=sum(self.history)
            )
        return None
