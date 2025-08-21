import os
import json
import time
from typing import List, Dict, Any

from fastapi import FastAPI, Request, HTTPException, Response
from starlette.responses import JSONResponse
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

# --- Minimal in-memory storage (swap to Firestore driver later) ----------------
class InMemoryStorage:
    def __init__(self, base_url: str = "memory://"):
        self._s: Dict[str, bytes] = {}
        self.base_url = base_url

    def put_bytes(self, key: str, data: bytes) -> None:
        self._s[key] = data

    def get_bytes(self, key: str) -> bytes:
        if key not in self._s:
            raise FileNotFoundError(key)
        return self._s[key]

    def exists(self, key: str) -> bool:
        return key in self._s

    def url_for(self, key: str) -> str:
        return f"{self.base_url}{key}"

STORAGE = InMemoryStorage()

# --- Keys ----------------------------------------------------------------------
def key_receipt(trace_id: str, hop_id: str) -> str:
    return f"receipts/{trace_id}/hops/{hop_id}.json"

def key_receipt_index(trace_id: str) -> str:
    return f"receipts/{trace_id}/index.json"

# --- App -----------------------------------------------------------------------
app = FastAPI(title="ODIN Secure Communication Layer")

# Prometheus metrics (keep labels minimal to avoid cardinality blowups)
HTTP_REQUESTS = Counter(
    "odin_http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status"]
)

# Back-compat counters for tests
REQUESTS = Counter("odin_requests_total", "Total requests", ["path"])  
GATEWAY_REQUESTS = Counter("odin_gateway_requests_total", "Gateway requests", ["path"])  

# Metrics middleware: increments even on exceptions, avoids /metrics path
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    status_code = 500
    resp = None
    try:
        resp = await call_next(request)
        status_code = resp.status_code
        return resp
    finally:
        path = request.url.path
        if path != "/metrics":
            # (No try/except holes here—this runs even if the handler raised)
            HTTP_REQUESTS.labels(
                method=request.method,
                path=path,
                status=str(status_code)
            ).inc()
            try:
                REQUESTS.labels(path=path).inc()
                GATEWAY_REQUESTS.labels(path=path).inc()
            except Exception:
                pass

# --- Health --------------------------------------------------------------------
@app.get("/health")
def health():
    return {"ok": True, "status": "ok"}

# --- Discovery & JWKS ----------------------------------------------------------
@app.get("/.well-known/odin/discovery.json")
def discovery():
    return {
        "protocol": "odin/secure-comm",
        "version": "1.0.0",
        "endpoints": {
            "jwks": "/.well-known/jwks.json",
            "envelope": "/v1/envelope",
            "receipts_list": "/v1/receipts/hops",
            "receipts_chain": "/v1/receipts/hops/chain/{trace_id}",
            "metrics": "/metrics",
            "health": "/health"
        }
    }

@app.get("/.well-known/jwks.json")
def jwks():
    # In production, serve public keys derived from Secret Manager.
    # For tests, a single static key id is fine.
    return {"keys": [{"kty": "OKP", "crv": "Ed25519", "kid": "gw-2025-08", "x": "REPLACE_ME"}]}

# --- Echo for policy size tests -----------------------------------------------
@app.post("/echo")
async def echo(request: Request):
    raw = await request.body()
    if len(raw) > MAX_BODY:
        raise HTTPException(status_code=413, detail="payload too large")
    return {"len": len(raw)}

# --- HEL-lite (size + headers) -------------------------------------------------
# Default HEL-lite size limit (64 KiB). Override via ODIN_MAX_BODY_BYTES if needed.
MAX_BODY = int(os.getenv("ODIN_MAX_BODY_BYTES", "65536"))

def enforce_hel(request: Request, raw: bytes):
    required = ["X-ODIN-Trace-Id", "X-ODIN-Payload-CID"]
    for h in required:
        if h not in request.headers:
            raise HTTPException(status_code=400, detail=f"missing header {h}")
    if len(raw) > MAX_BODY:
        raise HTTPException(status_code=413, detail="payload too large")

# --- Envelope -> minimal signed receipt ---------------------------------------
@app.post("/v1/envelope")
async def envelope(request: Request):
    raw = await request.body()
    enforce_hel(request, raw)

    try:
        body = json.loads(raw.decode("utf-8")) if raw else {}
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="invalid JSON payload")

    trace_id = request.headers.get("X-ODIN-Trace-Id")
    payload_cid = request.headers.get("X-ODIN-Payload-CID")
    hop_id = str(int(time.time() * 1000))[-6:]  # simple monotonic-ish hop id

    receipt = {
        "trace_id": trace_id,
        "hop_id": hop_id,
        "payload_cid": payload_cid,
        "policy": {"verdict": "allow", "rules": ["required-headers", f"size<={MAX_BODY}"]},
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        # In prod, sign with Ed25519; tests only need a stable kid.
        "signature": {"kid": "gw-2025-08", "alg": "EdDSA", "sig": "stub"}
    }

    # Persist receipt + index
    STORAGE.put_bytes(key_receipt(trace_id, hop_id), json.dumps(receipt).encode("utf-8"))
    idx_key = key_receipt_index(trace_id)
    index: List[Dict[str, Any]] = []
    if STORAGE.exists(idx_key):
        index = json.loads(STORAGE.get_bytes(idx_key).decode("utf-8"))
    index.append({"hop_id": hop_id})
    STORAGE.put_bytes(idx_key, json.dumps(index).encode("utf-8"))

    return JSONResponse(status_code=201, content={"ok": True, "receipt": receipt})

# --- Receipts listing & chain --------------------------------------------------
@app.get("/v1/receipts/hops")
def list_hops(trace_id: str):
    idx_key = key_receipt_index(trace_id)
    if not STORAGE.exists(idx_key):
        return {"hops": []}
    index = json.loads(STORAGE.get_bytes(idx_key).decode("utf-8"))
    return {"hops": index}

@app.get("/v1/receipts/hops/chain/{trace_id}")
def get_chain(trace_id: str):
    idx_key = key_receipt_index(trace_id)
    if not STORAGE.exists(idx_key):
        return {"chain": []}
    index = json.loads(STORAGE.get_bytes(idx_key).decode("utf-8"))
    chain = []
    for hop in index:
        rec = json.loads(STORAGE.get_bytes(key_receipt(trace_id, hop["hop_id"]))
                         .decode("utf-8"))
        chain.append(rec)
    return {"chain": chain}

# --- Prometheus scrape endpoint ------------------------------------------------
@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
