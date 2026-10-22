"""بوابة التشخيص: تستقبل صورة نبات، تحلّلها بنموذج رؤية يعمل محليًا عبر
Ollama، وترجع تشخيصًا منظّمًا بالعربية. لا تتصل بأي خدمة ذكاء اصطناعي خارجية."""
from __future__ import annotations

import asyncio
import base64
import hmac
import io
import logging
import os
from contextlib import asynccontextmanager

import httpx
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

from parsing import SCHEMA, build_messages, extract_json, normalize

log = logging.getLogger("gateway")
logging.basicConfig(level=logging.INFO)

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://ollama:11434").rstrip("/")
MODEL = os.environ.get("OLLAMA_MODEL", "qwen2.5vl:7b")
API_KEY = os.environ.get("API_KEY", "")
MAX_UPLOAD_BYTES = int(os.environ.get("MAX_UPLOAD_MB", "8")) * 1024 * 1024
MAX_SIDE = int(os.environ.get("MAX_IMAGE_SIDE", "1024"))
REQUEST_TIMEOUT = float(os.environ.get("REQUEST_TIMEOUT_S", "300"))
MAX_WAITING = int(os.environ.get("MAX_WAITING", "4"))
MAX_CONCURRENT = int(os.environ.get("MAX_CONCURRENT", "1"))

_gpu_slots = asyncio.Semaphore(MAX_CONCURRENT)
_waiting = 0


@asynccontextmanager
async def lifespan(_: FastAPI):
    if len(API_KEY) < 16:
        raise RuntimeError("API_KEY must be set (at least 16 characters)")
    yield


app = FastAPI(title="Nabati Plant Diagnosis", lifespan=lifespan)


def require_key(x_api_key: str = Header(default="")) -> None:
    if not hmac.compare_digest(x_api_key.encode(), API_KEY.encode()):
        raise HTTPException(status_code=401, detail="invalid api key")


def prepare_image(data: bytes) -> str:
    """Validate, strip metadata, shrink, and return base64 JPEG."""
    try:
        with Image.open(io.BytesIO(data)) as img:
            if img.format not in ("JPEG", "PNG", "WEBP"):
                raise HTTPException(415, "only JPEG, PNG or WEBP images")
            img = ImageOps.exif_transpose(img).convert("RGB")
            img.thumbnail((MAX_SIDE, MAX_SIDE))
            out = io.BytesIO()
            img.save(out, format="JPEG", quality=90)
    except (UnidentifiedImageError, OSError) as exc:
        raise HTTPException(400, "not a valid image") from exc
    return base64.b64encode(out.getvalue()).decode()


@app.get("/health")
async def health() -> dict:
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{OLLAMA_URL}/api/tags")
            r.raise_for_status()
            names = [m.get("name") for m in r.json().get("models", [])]
    except Exception:
        raise HTTPException(503, "model server unavailable") from None
    return {"status": "ok", "model": MODEL, "model_ready": MODEL in names}


@app.post("/v1/diagnose", dependencies=[Depends(require_key)])
async def diagnose(
    image: UploadFile = File(...),
    crop: str | None = Form(default=None),
) -> dict:
    global _waiting
    data = await image.read(MAX_UPLOAD_BYTES + 1)
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "image too large")
    image_b64 = prepare_image(data)

    if _waiting >= MAX_WAITING:
        raise HTTPException(429, "server busy, try again shortly")
    _waiting += 1
    try:
        async with _gpu_slots:
            payload = {
                "model": MODEL,
                "messages": build_messages(image_b64, (crop or "")[:60]),
                "stream": False,
                "format": SCHEMA,
                "options": {"temperature": 0.2},
            }
            try:
                async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
                    r = await client.post(f"{OLLAMA_URL}/api/chat", json=payload)
                    r.raise_for_status()
                    content = r.json()["message"]["content"]
            except httpx.TimeoutException:
                raise HTTPException(504, "model timed out") from None
            except (httpx.HTTPError, KeyError, ValueError) as exc:
                log.error("ollama call failed: %s", exc)
                raise HTTPException(502, "model server error") from None
    finally:
        _waiting -= 1

    try:
        result = normalize(extract_json(content))
    except ValueError as exc:
        log.error("bad model output: %s", exc)
        raise HTTPException(502, "model returned an unusable answer") from None
    result["model"] = MODEL
    return result
