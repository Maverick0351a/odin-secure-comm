import base64
from typing import Dict, Any

# Simple in-memory public key set for discovery; replace with rotating key store.
# Ed25519 public key in raw 32-byte form; base64url without padding for jwks 'x'.
# For scaffold, we generate a constant placeholder. Do not use in production.

_PLACEHOLDER_PUB_B64URL = base64.urlsafe_b64encode(b"0" * 32).rstrip(b"=").decode()


def get_jwks() -> Dict[str, Any]:
    return {
        "keys": [
            {
                "kty": "OKP",
                "crv": "Ed25519",
                "kid": "gw-2025-08",
                "alg": "EdDSA",
                "use": "sig",
                "x": _PLACEHOLDER_PUB_B64URL,
            }
        ]
    }
