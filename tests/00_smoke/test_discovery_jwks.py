from fastapi.testclient import TestClient
from services.gateway.app import app

def test_jwks_exposed():
    c = TestClient(app)
    r = c.get("/.well-known/jwks.json")
    assert r.status_code == 200
    data = r.json()
    assert "keys" in data and isinstance(data["keys"], list)
    k = data["keys"][0]
    assert k["kty"] == "OKP" and k["crv"] == "Ed25519"
