from fastapi import Request
from .hel import check_payload_size, check_required_headers

async def enforce_hel(request: Request, call_next):
    body = await request.body()
    ok, reason = check_payload_size(len(body))
    if not ok:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=413, content={"error": reason})
    # For envelope endpoint, ensure required headers exist
    if request.url.path == "/v1/envelope":
        try:
            payload = await request.json()
            headers = payload.get("headers", {})
        except Exception:
            headers = {}
        ok, reason = check_required_headers(headers)
        if not ok:
            from fastapi.responses import JSONResponse
            return JSONResponse(status_code=400, content={"error": reason})
    return await call_next(request)
