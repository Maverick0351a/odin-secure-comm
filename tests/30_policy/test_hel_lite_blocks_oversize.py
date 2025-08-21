from fastapi.testclient import TestClient
from services.gateway.app import app

def test_oversize_payload_blocked():
    c = TestClient(app)
    big = b"x" * (64 * 1024 + 1)
    r = c.post("/echo", data=big)
    assert r.status_code == 413


def test_under_limit_allowed():
    c = TestClient(app)
    ok = b"x" * (64 * 1024)
    r = c.post("/echo", data=ok)
    assert r.status_code == 200
    assert r.json()["len"] == len(ok)
