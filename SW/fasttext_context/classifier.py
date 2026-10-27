"""Text classifier plus explicit context guards; no LLM generation or audio model."""

import re

NEGATED_FIRE = re.compile(
    r"화재[^.!?\n]{0,18}(발생하지\s*않|아니|없[습음어요])|불이?\s*나지\s*않|대피(하지\s*않|[^.!?\n]{0,8}필요[가\s]*없)"
)
DRILL = re.compile(r"훈련|연습|테스트|시연|시나리오|가정|실험|예시|예방|오보|취소|해제")
EXPLICIT = re.compile(
    r"화재가?\s*(발생|났)|불이\s*났|가스\s*누출|대피(하|해|\s*바랍)|비상[^.!?\n]{0,12}대피"
)


class FireTextClassifier:
    def __init__(self, model):
        self.model = model

    def classify(self, text):
        # Preserve clause boundaries for rules; fastText's native predict API
        # expects a single line, so flatten only its separate input.
        text = str(text).replace("\r\n", "\n").replace("\r", "\n")
        text = re.sub(r"[^\S\n]+", " ", text).strip()[:1000]
        labels, scores = self.model.predict(" ".join(text.split()), k=1)
        label = labels[0].replace("__label__", "")
        score = float(scores[0])
        # This model was observed to score a negated fire sentence as FIRE.
        # Its score is not a calibrated risk probability.
        clauses = [part.strip() for part in re.split(r"[.!?\n]+", text) if part.strip()]
        explicit = any(EXPLICIT.search(part) and not NEGATED_FIRE.search(part)
                       and not DRILL.search(part) for part in clauses)
        if explicit:
            hazard, reason = True, "explicit_announcement"
        elif NEGATED_FIRE.search(text):
            hazard, reason = False, "negated_fire"
        elif DRILL.search(text):
            hazard, reason = False, "drill_or_reference"
        else:
            hazard, reason = False, "insufficient_explicit_evidence"
        return dict(
            text=text, label=label, model_score=score, hazard=hazard, reason=reason
        )


def summarize_context(payload, classifier):
    context = payload.get("selected_context", {})
    if isinstance(context, str):
        import json

        try:
            context = json.loads(context)
        except ValueError:
            context = {}
    if not isinstance(context, dict):
        context = {}
    workflow = context.get("workflow") or {}
    if not isinstance(workflow, dict):
        workflow = {}
    scenario = workflow.get("scenario")
    if scenario == "broadcast":
        return "위험 안내방송이 감지됐어요. 화면의 원문과 대피 안내를 확인하고 수어·터치로 응답해 주세요."
    if scenario == "disaster":
        return "새 재난 안내가 있어요. 발행 지역·시각과 원문을 확인하고 수어·터치로 응답해 주세요."
    if scenario == "assistance":
        return "도움 요청 또는 이상 움직임이 감지됐어요. 낙상·의식 상태는 미확인이니 수어·터치로 상황을 알려주세요."
    captions = context.get("recent_dialogue") or []
    text = (
        str(captions[-1])
        if isinstance(captions, list) and captions
        else str(payload.get("source", ""))
    )
    if text:
        result = classifier.classify(text)
        if result["hazard"]:
            return "위험 안내로 볼 수 있는 말이 있어요. 자막 원문과 현재 상황을 확인해 주세요."
        if result["reason"] == "negated_fire":
            return "화재 발생을 부정하는 표현이 있어요. 이 문장만으로 위험 경보를 새로 켜지 않아요."
        if result["reason"] == "drill_or_reference":
            return "훈련·예방 또는 상황을 설명하는 표현이 있어요. 기존 경보와 원문을 함께 확인해 주세요."
    return "새 위험을 확정할 정보는 없어요. 방송·재난·센서 정보를 계속 확인하고 있어요."
