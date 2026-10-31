from __future__ import annotations

import base64
import binascii
import json
import logging
import threading
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError
from firebase_admin import firestore, initialize_app
from firebase_functions import https_fn, options

initialize_app()

_MODEL_PATH = Path(__file__).parent / "plant_disease_classifier.tflite"
_LABELS_PATH = Path(__file__).parent / "labels.json"
_TREATMENTS_PATH = Path(__file__).parent / "treatments.json"
_MAX_IMAGE_BYTES = 5 * 1024 * 1024
_MAX_IMAGE_PIXELS = 25_000_000
_MAX_DAILY_REQUESTS = 10
_MODEL_VERSION = "plantvillage-mobilenetv2-38-v1"
_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}

_model_lock = threading.Lock()
_treatment_lock = threading.Lock()
_model: Any | None = None
_labels: list[dict[str, str]] | None = None
_treatment_data: dict[str, Any] | None = None

_TREATMENT_KEY_BY_CLASS = {
    "Apple___Apple_scab": "apple__scab",
    "Potato___Early_blight": "potato__early_blight",
    "Potato___Late_blight": "potato__late_blight",
    "Squash___Powdery_mildew": "squash__powdery_mildew",
    "Tomato___Bacterial_spot": "tomato__bacterial_spot",
    "Tomato___Early_blight": "tomato__early_blight",
    "Tomato___Late_blight": "tomato__late_blight",
    "Tomato___Spider_mites Two-spotted_spider_mite": "tomato__spider_mite",
}


def _error(code: https_fn.FunctionsErrorCode, message: str) -> https_fn.HttpsError:
    return https_fn.HttpsError(code=code, message=message)


def _load_model() -> tuple[Any, list[dict[str, str]]]:
    global _model, _labels
    if _model is not None and _labels is not None:
        return _model, _labels

    with _model_lock:
        if _model is not None and _labels is not None:
            return _model, _labels
        if not _MODEL_PATH.is_file() or not _LABELS_PATH.is_file():
            logging.error("Plant disease model assets are missing from the deployment bundle")
            raise RuntimeError("المصنف غير مهيأ على الخادم.")

        try:
            from ai_edge_litert.interpreter import Interpreter

            parsed_labels = json.loads(_LABELS_PATH.read_text(encoding="utf-8"))
            if not isinstance(parsed_labels, list) or len(parsed_labels) != 38:
                raise ValueError("Expected exactly 38 ordered class labels")

            interpreter = Interpreter(model_path=str(_MODEL_PATH), num_threads=2)
            interpreter.allocate_tensors()
            input_details = interpreter.get_input_details()
            output_details = interpreter.get_output_details()
            if len(input_details) != 1 or len(output_details) != 1:
                raise ValueError("Expected one model input and one model output")
            output_size = int(np.prod(output_details[0]["shape"]))
            if output_size != len(parsed_labels):
                raise ValueError("The model output count does not match labels.json")

            _model = interpreter
            _labels = parsed_labels
            return _model, _labels
        except Exception as exc:
            logging.exception("Plant disease model initialization failed")
            raise RuntimeError("تعذر تهيئة مصنف الأمراض.") from exc


def _load_treatment_data() -> dict[str, Any]:
    global _treatment_data
    if _treatment_data is not None:
        return _treatment_data

    with _treatment_lock:
        if _treatment_data is None:
            if not _TREATMENTS_PATH.is_file():
                raise RuntimeError("ملف قاعدة العلاج غير موجود على الخادم.")
            parsed = json.loads(_TREATMENTS_PATH.read_text(encoding="utf-8"))
            if not isinstance(parsed, dict) or not isinstance(parsed.get("agri_treatments"), dict):
                raise ValueError("Invalid treatment database schema")
            _treatment_data = parsed
    return _treatment_data


def _treatment_for(class_name: str) -> dict[str, Any]:
    database = _load_treatment_data()
    record_id = _TREATMENT_KEY_BY_CLASS.get(class_name)
    record = database.get("agri_treatments", {}).get(record_id) if record_id else None
    source_verified = database.get("source_status") == "verified"
    record_verified = bool(record) and record.get("pesticide_recommendation_status") == "verified_active"
    products = record.get("approved_pesticides", []) if record and source_verified and record_verified else []

    if not record:
        return {
            "matched": False,
            "recordId": None,
            "noticeAr": "لا توجد مطابقة دقيقة لهذه الفئة في قاعدة العلاج المرفقة؛ لا تعرض توصية مبيد.",
            "source": database.get("source"),
            "section": database.get("section_name"),
            "sourceStatus": database.get("source_status"),
            "sourceVerificationNoteAr": database.get("source_verification_note_ar"),
            "approvedPesticides": [],
        }

    return {
        "matched": True,
        "recordId": record_id,
        "cropAr": record.get("crop_ar"),
        "diseaseAr": record.get("disease_ar"),
        "category": record.get("category"),
        "symptomsAr": record.get("symptoms"),
        "controlTimingAr": record.get("control_timing"),
        "pesticideRecommendationStatus": record.get("pesticide_recommendation_status"),
        "noticeAr": record.get("pesticide_recommendation_notice_ar"),
        "source": database.get("source"),
        "section": database.get("section_name"),
        "sourceStatus": database.get("source_status"),
        "sourceVerificationNoteAr": database.get("source_verification_note_ar"),
        "approvedPesticides": products,
    }


def _decode_image(encoded: str, mime_type: str) -> Image.Image:
    if mime_type not in _ALLOWED_MIME_TYPES:
        raise _error(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            "ارفع صورة بصيغة JPG أو PNG أو WebP.",
        )
    if not isinstance(encoded, str) or not encoded:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "الصورة المرسلة فارغة.")
    if len(encoded) > ((_MAX_IMAGE_BYTES + 2) // 3) * 4 + 8:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "حجم الصورة أكبر من الحد المسموح.")

    try:
        raw = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "بيانات الصورة غير صالحة.") from exc
    if not raw or len(raw) > _MAX_IMAGE_BYTES:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "حجم الصورة أكبر من 5 ميجابايت أو فارغ.")

    try:
        with Image.open(BytesIO(raw)) as source:
            if source.width <= 0 or source.height <= 0 or source.width * source.height > _MAX_IMAGE_PIXELS:
                raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "أبعاد الصورة أكبر من الحد الآمن.")
            source.verify()
        with Image.open(BytesIO(raw)) as source:
            image = ImageOps.exif_transpose(source).convert("RGB")
            image.load()
            return image
    except https_fn.HttpsError:
        raise
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as exc:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "تعذر قراءة الصورة. جرّب صورة أوضح بصيغة JPG أو PNG.") from exc


def _reserve_daily_request(uid: str) -> None:
    """Apply a small server-side per-user quota without persisting image data."""
    db = firestore.client()
    usage_ref = db.collection("_server_ai_usage").document(uid)
    today = datetime.now(timezone.utc).date().isoformat()
    transaction = db.transaction()

    @firestore.transactional
    def update_counter(tx: Any) -> None:
        snapshot = usage_ref.get(transaction=tx)
        previous = snapshot.to_dict() or {}
        count = int(previous.get("count", 0)) + 1 if previous.get("date") == today else 1
        if count > _MAX_DAILY_REQUESTS:
            raise _error(
                https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                "تم الوصول إلى الحد اليومي لتشخيص الصور. حاول غدًا.",
            )
        tx.set(
            usage_ref,
            {"date": today, "count": count, "updatedAt": firestore.SERVER_TIMESTAMP},
        )

    update_counter(transaction)


def _model_input(image: Image.Image, input_detail: dict[str, Any]) -> np.ndarray:
    resized = image.resize((224, 224), Image.Resampling.LANCZOS)
    tensor = np.asarray(resized, dtype=np.float32) / 127.5 - 1.0
    tensor = np.expand_dims(tensor, axis=0)

    expected_shape = tuple(int(value) for value in input_detail["shape"])
    if expected_shape != (1, 224, 224, 3):
        raise RuntimeError(f"Unsupported model input shape: {expected_shape}")

    dtype = input_detail["dtype"]
    if np.issubdtype(dtype, np.floating):
        return tensor.astype(dtype)

    scale, zero_point = input_detail.get("quantization", (0.0, 0))
    if not scale:
        raise RuntimeError("Quantized model input is missing its scale")
    limits = np.iinfo(dtype)
    quantized = np.rint(tensor / scale + zero_point)
    return np.clip(quantized, limits.min, limits.max).astype(dtype)


def _probabilities(output: np.ndarray, output_detail: dict[str, Any]) -> np.ndarray:
    values = np.asarray(output).reshape(-1).astype(np.float32)
    dtype = output_detail["dtype"]
    if np.issubdtype(dtype, np.integer):
        scale, zero_point = output_detail.get("quantization", (0.0, 0))
        if scale:
            values = (values - float(zero_point)) * float(scale)

    if values.size != 38 or not np.all(np.isfinite(values)):
        raise RuntimeError("The classifier returned invalid probabilities")
    if np.all(values >= 0.0) and float(values.sum()) > 0.0:
        probabilities = values / values.sum()
    else:
        shifted = values - float(np.max(values))
        exponentials = np.exp(shifted)
        probabilities = exponentials / float(exponentials.sum())
    return probabilities


def _classify(image: Image.Image) -> list[dict[str, Any]]:
    interpreter, labels = _load_model()
    with _model_lock:
        input_detail = interpreter.get_input_details()[0]
        output_detail = interpreter.get_output_details()[0]
        interpreter.set_tensor(input_detail["index"], _model_input(image, input_detail))
        interpreter.invoke()
        output = interpreter.get_tensor(output_detail["index"])

    probabilities = _probabilities(output, output_detail)
    best = np.argsort(probabilities)[-3:][::-1]
    return [
        {
            "className": labels[int(index)]["class"],
            "nameAr": labels[int(index)]["name_ar"],
            "cropAr": labels[int(index)]["crop_ar"],
            "confidence": float(probabilities[index]),
        }
        for index in best
    ]


@https_fn.on_call(
    enforce_app_check=True,
    region="europe-west1",
    memory=options.MemoryOption.MB_512,
    timeout_sec=60,
    max_instances=3,
)
def classifyPlantDisease(request: https_fn.CallableRequest) -> dict[str, Any]:
    """Classify a leaf photo with the custom 38-class PlantVillage TFLite model."""
    if request.auth is None or not request.auth.uid:
        raise _error(
            https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            "سجّل الدخول أولاً لاستخدام تشخيص الصور.",
        )
    if request.app is None:
        raise _error(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            "تعذر التحقق من سلامة التطبيق. حدّث التطبيق وحاول مجددًا.",
        )
    if not isinstance(request.data, dict):
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "بيانات الطلب غير صالحة.")
    if set(request.data) != {"mimeType", "imageBase64"}:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "حقول الطلب غير صالحة.")

    mime_type = request.data.get("mimeType")
    image_base64 = request.data.get("imageBase64")
    if not isinstance(mime_type, str) or not isinstance(image_base64, str):
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "أرسل صورة صالحة للتحليل.")

    image = _decode_image(image_base64, mime_type)
    try:
        _reserve_daily_request(request.auth.uid)
        predictions = _classify(image)
        treatment = _treatment_for(predictions[0]["className"])
    except https_fn.HttpsError:
        raise
    except Exception as exc:
        logging.exception("Plant disease classification request failed")
        raise _error(
            https_fn.FunctionsErrorCode.INTERNAL,
            "تعذر تحليل الصورة الآن. حاول مرة أخرى لاحقًا.",
        ) from exc

    return {
        "modelVersion": _MODEL_VERSION,
        "predictions": predictions,
        "treatment": treatment,
        "disclaimer": (
            "النتائج احتمالات أولية من فئات PlantVillage وليست تشخيصًا مؤكدًا. "
            "قد يخطئ النموذج في صور الحقول أو المحاصيل غير الموجودة ضمن فئاته. "
            "لا يقدّم جرعات مبيدات أو وصفات علاجية."
        ),
    }
