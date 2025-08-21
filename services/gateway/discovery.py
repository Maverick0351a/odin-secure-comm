from typing import Dict, Any


def openid_configuration(base_url: str) -> Dict[str, Any]:
    return {
        "jwks_uri": f"{base_url}/.well-known/jwks.json",
        "issuer": base_url,
        "id_token_signing_alg_values_supported": ["EdDSA"],
    }
