"""End-to-end check of the gateway against a fake Ollama server.

Needs the gateway requirements installed (run in CI / inside the image):
    python tests/e2e_fake_ollama.py
"""
import io
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

ANSWER = {
    "is_plant": True,
    "plant_name_ar": "طماطم",
    "health_status": "diseased",
    "diagnosis_ar": "اللفحة المبكرة",
    "confidence": 88,
    "symptoms": ["بقع بنية"],
    "treatment_organic": ["إزالة الأوراق المصابة"],
    "treatment_chemical": ["مبيد فطري نحاسي"],
    "prevention": ["تجنب الري بالرش"],
    "needs_expert": False,
}
SEEN = {}


class FakeOllama(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, obj):
        body = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._send({"models": [{"name": "fake:1"}]})

    def do_POST(self):
        length = int(self.headers["Content-Length"])
        SEEN["request"] = json.loads(self.rfile.read(length))
        self._send({"message": {"content": json.dumps(ANSWER, ensure_ascii=False)}})


server = HTTPServer(("127.0.0.1", 0), FakeOllama)
threading.Thread(target=server.serve_forever, daemon=True).start()

os.environ["OLLAMA_URL"] = f"http://127.0.0.1:{server.server_port}"
os.environ["OLLAMA_MODEL"] = "fake:1"
os.environ["API_KEY"] = "k" * 24

from fastapi.testclient import TestClient  # noqa: E402
from PIL import Image  # noqa: E402

import main  # noqa: E402

buf = io.BytesIO()
Image.new("RGB", (2000, 1500), (30, 160, 40)).save(buf, format="JPEG")
good = {"image": ("leaf.jpg", buf.getvalue(), "image/jpeg")}
headers = {"X-API-Key": "k" * 24}

with TestClient(main.app) as client:
    assert client.get("/health").json()["model_ready"] is True

    r = client.post("/v1/diagnose", files=good)
    assert r.status_code == 401, r.text

    r = client.post("/v1/diagnose", files=good, headers={"X-API-Key": "wrong"})
    assert r.status_code == 401, r.text

    r = client.post(
        "/v1/diagnose", files=good, headers=headers, data={"crop": "طماطم"}
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["plant_name_ar"] == "طماطم"
    assert abs(body["confidence"] - 0.88) < 1e-9, body
    assert body["disclaimer"] and body["model"] == "fake:1"

    sent = SEEN["request"]
    assert sent["model"] == "fake:1" and sent["stream"] is False
    assert len(sent["messages"][1]["images"]) == 1
    # الصورة اتصغّرت قبل ما تتبعت للنموذج
    img = Image.open(io.BytesIO(__import__("base64").b64decode(sent["messages"][1]["images"][0])))
    assert max(img.size) <= main.MAX_SIDE, img.size

    r = client.post(
        "/v1/diagnose",
        files={"image": ("x.jpg", b"not an image", "image/jpeg")},
        headers=headers,
    )
    assert r.status_code == 400, r.text

print("e2e ok")
