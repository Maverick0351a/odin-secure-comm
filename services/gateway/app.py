import os
import json
import time
import logging
from typing import List, Dict, Any

from fastapi import FastAPI, Request, HTTPException, Response
from starlette.responses import JSONResponse
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
from .jwks_loader import load_active_key, jwk_from_pub, sign_bytes
from .storage import InMemoryStorage, FirestoreStorage
from libs.odin.crypto import b64url_no_pad
from starlette.middleware.cors import CORSMiddleware

# --- Storage driver selection --------------------------------------------------
driver = os.getenv("ODIN_STORAGE", "memory").lower()
if driver == "firestore" and FirestoreStorage is not None:
    # project/collection can be provided via env; both optional
    project = os.getenv("ODIN_GCP_PROJECT") or os.getenv("GOOGLE_CLOUD_PROJECT")
    collection = os.getenv("ODIN_FS_COLLECTION", "receipts")
    try:
        STORAGE = FirestoreStorage(project=project, collection=collection)  # type: ignore
    except Exception:
        # Fallback to memory if Firestore unavailable/misconfigured
        STORAGE = InMemoryStorage()
else:
    STORAGE = InMemoryStorage()

# --- Keys ----------------------------------------------------------------------
def key_receipt(trace_id: str, hop_id: str) -> str:
    return f"receipts/{trace_id}/hops/{hop_id}.json"

def key_receipt_index(trace_id: str) -> str:
    return f"receipts/{trace_id}/index.json"

# --- App -----------------------------------------------------------------------
app = FastAPI(title="ODIN Secure Communication Layer")
# Load active signing key once
_PRIV, _PUB, _KID = load_active_key()

# Optional CORS (off by default). Set ODIN_CORS_ORIGINS="https://example.com,https://app.example.com" to enable.
_cors_origins = os.getenv("ODIN_CORS_ORIGINS")
if _cors_origins:
    origins = [o.strip() for o in _cors_origins.split(",") if o.strip()]
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=False,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["*"]
        )

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

# JSON logging middleware with sensitive header redaction
LOG_LEVEL = os.getenv("ODIN_LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO))
_logger = logging.getLogger("odin.gateway")

def _redacted_headers(h: Dict[str, str]) -> Dict[str, Any]:
    # Minimal set with redaction; header keys are case-insensitive
    get = h.get
    out = {
        "x_odin_trace_id": get("X-ODIN-Trace-Id"),
        "x_odin_payload_cid": get("X-ODIN-Payload-CID"),
        "user_agent": get("User-Agent"),
    }
    if get("authorization") or get("Authorization"):
        out["authorization"] = "REDACTED"
    if get("x-api-key") or get("X-API-Key"):
        out["x_api_key"] = "REDACTED"
    return out

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    t0 = time.time()
    status_code = 500
    try:
        resp = await call_next(request)
        status_code = resp.status_code
        return resp
    finally:
        dt_ms = int((time.time() - t0) * 1000)
        try:
            client_ip = request.client.host if request.client else None
        except Exception:
            client_ip = None
        log_obj = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "method": request.method,
            "path": request.url.path,
            "status": status_code,
            "duration_ms": dt_ms,
            "remote_ip": client_ip,
            "headers": _redacted_headers(request.headers),
        }
        _logger.info(json.dumps(log_obj, separators=(",", ":")))

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
    return {"keys": [jwk_from_pub(_PUB, _KID)]}

# --- Echo for policy size tests -----------------------------------------------
@app.post("/echo")
async def echo(request: Request):
    raw = await request.body()
    # Use HEL-lite guard; for /echo we only enforce size to keep tests lenient
    enforce_hel(request, raw)
    accept = request.headers.get("accept", "")
    if "application/octet-stream" in accept:
        return Response(content=raw, media_type="application/octet-stream")
    # Default JSON summary for tests
    return {"len": len(raw)}

# --- HEL-lite (size + headers) -------------------------------------------------
# Default HEL-lite size limit (64 KiB). Override via ODIN_MAX_BODY_BYTES if needed.
MAX_BODY = int(os.getenv("ODIN_MAX_BODY_BYTES", "65536"))

def enforce_hel(request: Request, raw: bytes):
    # For /echo, only enforce size limit to keep developer ergonomics/tests simple
    if request.url.path != "/echo":
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

    # Sign the canonical string "trace_id.payload_cid" per spec
    sig_input = f"{trace_id}.{payload_cid}".encode("utf-8")
    sig = sign_bytes(_PRIV, sig_input)
    receipt = {
        "trace_id": trace_id,
        "hop_id": hop_id,
        "payload_cid": payload_cid,
        "policy": {"verdict": "allow", "rules": ["required-headers", f"size<={MAX_BODY}"]},
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "signature": {"kid": _KID, "alg": "EdDSA", "sig": b64url_no_pad(sig)}
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
