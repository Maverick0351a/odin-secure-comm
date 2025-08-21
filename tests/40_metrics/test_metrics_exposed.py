from fastapi.testclient import TestClient
from services.gateway.app import app

def test_metrics_endpoint():
    c = TestClient(app)
    r = c.get("/metrics")
    assert r.status_code == 200
    assert b"odin_requests_total" in r.content or b"odin_gateway_requests_total" in r.content
