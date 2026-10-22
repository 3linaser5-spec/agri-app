"""Pure helpers (no third-party imports) for the diagnosis gateway.

Kept separate so they can be unit tested with the standard library only.
"""
from __future__ import annotations

import json
import re
from typing import Any

HEALTH_STATES = ("healthy", "diseased", "pest", "deficiency", "unclear")
SEVERITIES = ("low", "medium", "high")

DISCLAIMER_AR = (
    "التشخيص آلي واسترشادي وقد يخطئ. راجع مهندسًا زراعيًا قبل استخدام أي "
    "مبيد، واقرأ نشرة المنتج والتزم بالجرعات المسجلة عليها."
)

# JSON schema passed to Ollama so the model must answer in this exact shape.
SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "is_plant": {"type": "boolean"},
        "plant_name_ar": {"type": "string"},
        "plant_name_scientific": {"type": "string"},
        "health_status": {"type": "string", "enum": list(HEALTH_STATES)},
        "diagnosis_ar": {"type": "string"},
        "diagnosis_en": {"type": "string"},
        "confidence": {"type": "number"},
        "severity": {"type": "string", "enum": list(SEVERITIES)},
        "symptoms": {"type": "array", "items": {"type": "string"}},
        "causes": {"type": "array", "items": {"type": "string"}},
        "treatment_organic": {"type": "array", "items": {"type": "string"}},
        "treatment_chemical": {"type": "array", "items": {"type": "string"}},
        "prevention": {"type": "array", "items": {"type": "string"}},
        "needs_expert": {"type": "boolean"},
        "notes": {"type": "string"},
    },
    "required": [
        "is_plant",
        "plant_name_ar",
        "health_status",
        "diagnosis_ar",
        "confidence",
        "symptoms",
        "treatment_organic",
        "treatment_chemical",
        "prevention",
        "needs_expert",
    ],
}

SYSTEM_PROMPT = """أنت مهندس زراعي خبير في أمراض النباتات والآفات ونقص العناصر.
حلّل صورة النبات وأجب بصيغة JSON فقط حسب المخطط المطلوب، وبالعربية الفصحى المبسطة.

القواعد:
- لو الصورة ليست نباتًا: is_plant=false وباقي الحقول فارغة، ولا تخمّن.
- حدّد النبات (الاسم العربي والعلمي إن عرفته) ثم حالته الصحية.
- لا تبالغ في الثقة: confidence رقم من 0 إلى 1، وإذا كانت الصورة غير واضحة
  أو الأعراض متشابهة بين أكثر من سبب فاجعل health_status="unclear"
  وقيمة confidence منخفضة، واجعل needs_expert=true.
- العلاج: قدّم أولًا الإجراءات الزراعية والعضوية، ثم الكيماوية.
  في العلاج الكيماوي اذكر المادة الفعالة أو مجموعتها فقط، ولا تذكر جرعات
  رقمية ولا أسماء تجارية، واطلب الالتزام بنشرة المنتج.
- اذكر الأعراض التي رأيتها فعلًا في الصورة، ولا تخترع أعراضًا.
- اجعل كل قائمة من 2 إلى 6 نقاط قصيرة وعملية."""


def build_user_prompt(crop: str | None) -> str:
    base = "شخّص هذا النبات وأعطني خطة علاج."
    crop = (crop or "").strip()
    if crop:
        base += f" المستخدم يقول إن المحصول هو: {crop} (تحقق من ذلك ولا تعتمد عليه)."
    return base


def build_messages(image_b64: str, crop: str | None) -> list[dict[str, Any]]:
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": build_user_prompt(crop),
            "images": [image_b64],
        },
    ]


def extract_json(text: str) -> dict[str, Any]:
    """Parse the model output. Tolerates ```json fences and extra prose."""
    text = (text or "").strip()
    if not text:
        raise ValueError("empty model output")
    fenced = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.DOTALL)
    if fenced:
        text = fenced.group(1)
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        start, end = text.find("{"), text.rfind("}")
        if start == -1 or end <= start:
            raise ValueError("model output is not JSON") from None
        try:
            value = json.loads(text[start : end + 1])
        except json.JSONDecodeError as exc:
            raise ValueError("model output is not valid JSON") from exc
    if not isinstance(value, dict):
        raise ValueError("model output is not a JSON object")
    return value


def _text(value: Any, limit: int = 400) -> str:
    return value.strip()[:limit] if isinstance(value, str) else ""


def _list(value: Any, max_items: int = 8) -> list[str]:
    if not isinstance(value, list):
        return []
    items = [_text(v, 300) for v in value]
    return [v for v in items if v][:max_items]


def normalize(raw: dict[str, Any]) -> dict[str, Any]:
    """Coerce whatever the model returned into the strict response shape."""
    is_plant = raw.get("is_plant") is True
    health = raw.get("health_status")
    if health not in HEALTH_STATES:
        health = "unclear"
    severity = raw.get("severity")
    if severity not in SEVERITIES:
        severity = None

    confidence = raw.get("confidence")
    if isinstance(confidence, bool) or not isinstance(confidence, (int, float)):
        confidence = 0.0
    confidence = float(confidence)
    if confidence > 1:  # model answered as a percentage
        confidence = confidence / 100
    confidence = max(0.0, min(1.0, confidence))

    if not is_plant:
        return {
            "is_plant": False,
            "plant_name_ar": "",
            "plant_name_scientific": "",
            "health_status": "unclear",
            "diagnosis_ar": "الصورة لا تحتوي على نبات واضح",
            "diagnosis_en": "",
            "confidence": 0.0,
            "severity": None,
            "symptoms": [],
            "causes": [],
            "treatment_organic": [],
            "treatment_chemical": [],
            "prevention": [],
            "needs_expert": False,
            "notes": "",
            "disclaimer": DISCLAIMER_AR,
        }

    needs_expert = raw.get("needs_expert") is True
    # الثقة المنخفضة أو الحالة غير الواضحة تعني دائمًا مراجعة مختص
    if confidence < 0.5 or health == "unclear":
        needs_expert = True

    return {
        "is_plant": True,
        "plant_name_ar": _text(raw.get("plant_name_ar"), 100),
        "plant_name_scientific": _text(raw.get("plant_name_scientific"), 100),
        "health_status": health,
        "diagnosis_ar": _text(raw.get("diagnosis_ar"), 200),
        "diagnosis_en": _text(raw.get("diagnosis_en"), 200),
        "confidence": confidence,
        "severity": severity,
        "symptoms": _list(raw.get("symptoms")),
        "causes": _list(raw.get("causes")),
        "treatment_organic": _list(raw.get("treatment_organic")),
        "treatment_chemical": _list(raw.get("treatment_chemical")),
        "prevention": _list(raw.get("prevention")),
        "needs_expert": needs_expert,
        "notes": _text(raw.get("notes"), 500),
        "disclaimer": DISCLAIMER_AR,
    }
