import base64
import os
from typing import Tuple, Optional

try:  # optional dependency
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives import serialization
except Exception:  # pragma: no cover
    Ed25519PrivateKey = None  # type: ignore

try:  # optional dependency
    from google.cloud import secretmanager  # type: ignore
except Exception:  # pragma: no cover
    secretmanager = None  # type: ignore

from libs.odin.crypto import b64url_no_pad


def _b64_to_bytes(s: str) -> bytes:
    # accept both std and url-safe base64 without padding
    s = s.strip()
    s = s.replace("-", "+").replace("_", "/")
    pad = "=" * (-len(s) % 4)
    return base64.b64decode(s + pad)


def _pub_from_priv(priv_bytes: bytes) -> bytes:
    # Try cryptography first
    if Ed25519PrivateKey is not None:
        try:
            priv = Ed25519PrivateKey.from_private_bytes(priv_bytes)
            return priv.public_key().public_bytes_raw()
        except Exception:
            pass
    # Fallback to PyNaCl
    try:
        import nacl.signing  # type: ignore

        sk = nacl.signing.SigningKey(priv_bytes)
        return bytes(sk.verify_key)
    except Exception as e:  # pragma: no cover
        raise RuntimeError("Unable to derive public key") from e


def load_ed25519_from_pem(pem: bytes) -> Tuple[bytes, bytes]:
    """Load a key from a minimal PEM/bytes artifact.

    For simplicity, if the input is raw 32-byte seed, use it directly.
    Otherwise, try to parse as PEM using cryptography; if that fails, take the last 32 bytes.
    Returns (priv_bytes, pub_bytes).
    """
    if len(pem) == 32:
        priv = pem
        return priv, _pub_from_priv(priv)
    # Try cryptography PEM parsing
    if Ed25519PrivateKey is not None:
        try:
            priv_key = serialization.load_pem_private_key(pem, password=None)
            if hasattr(priv_key, "private_bytes"):
                raw = priv_key.private_bytes(
                    encoding=serialization.Encoding.Raw,
                    format=serialization.PrivateFormat.Raw,
                    encryption_algorithm=serialization.NoEncryption(),
                )
                return raw, _pub_from_priv(raw)
        except Exception:
            pass
    # Last-resort heuristic: use last 32 bytes as seed
    raw = pem[-32:]
    return raw, _pub_from_priv(raw)


def jwk_from_pub(pub: bytes, kid: str) -> dict:
    return {"kty": "OKP", "crv": "Ed25519", "kid": kid, "x": b64url_no_pad(pub)}


def load_priv_from_env() -> Optional[Tuple[bytes, bytes, str]]:
    kid = os.getenv("ODIN_KID")
    # Preferred: explicit base64 form
    b64 = os.getenv("ODIN_ED25519_PRIV_B64")
    if b64:
        raw = _b64_to_bytes(b64)
        pub = _pub_from_priv(raw)
        return raw, pub, kid or _default_kid()
    
    # Check for Secret Manager resource name format (projects/.../secrets/.../versions/...)
    jwks_priv = os.getenv("ODIN_JWKS_PRIV")
    if jwks_priv:
        # If it looks like a Secret Manager resource name, load from Secret Manager
        if jwks_priv.startswith("projects/") and "/secrets/" in jwks_priv:
            return load_priv_from_gcp_secret_resource(jwks_priv)
        else:
            # Raw PEM or raw 32-byte seed encoded as text
            data = jwks_priv.encode("utf-8")
            priv, pub = load_ed25519_from_pem(data)
            return priv, pub, kid or _default_kid()
    return None


def load_priv_from_gcp_secret() -> Optional[Tuple[bytes, bytes, str]]:
    if secretmanager is None:
        return None
    secret_id = os.getenv("ODIN_GCP_SECRET_ID")
    project = os.getenv("ODIN_GCP_PROJECT") or os.getenv("GOOGLE_CLOUD_PROJECT")
    kid = os.getenv("ODIN_KID")
    if not secret_id or not project:
        return None
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project}/secrets/{secret_id}/versions/latest"
    resp = client.access_secret_version(name=name)
    data = resp.payload.data  # bytes
    # Try parse as PEM or raw seed
    priv, pub = load_ed25519_from_pem(data)
    return priv, pub, kid or _default_kid()


def load_priv_from_gcp_secret_resource(resource_name: str) -> Optional[Tuple[bytes, bytes, str]]:
    """Load private key from Secret Manager using full resource name."""
    if secretmanager is None:
        return None
    try:
        client = secretmanager.SecretManagerServiceClient()
        resp = client.access_secret_version(name=resource_name)
        data = resp.payload.data  # bytes
        # Try parse as PEM or raw seed
        priv, pub = load_ed25519_from_pem(data)
        kid = os.getenv("ODIN_KID") or _default_kid()
        return priv, pub, kid
    except Exception:
        return None


def _default_kid() -> str:
    import datetime as _dt

    now = _dt.datetime.utcnow()
    return f"gw-{now.year}-{now.month:02d}"


def load_active_key() -> Tuple[bytes, bytes, str]:
    # 1) ODIN_ED25519_PRIV_B64 env
    v = load_priv_from_env()
    if v:
        return v
    # 2) GCP Secret Manager
    v = load_priv_from_gcp_secret()
    if v:
        return v
    # 3) Fallback: ephemeral key
    import nacl.signing  # type: ignore

    sk = nacl.signing.SigningKey.generate()
    raw = bytes(sk)
    pub = bytes(sk.verify_key)
    return raw, pub, _default_kid()


def sign_bytes(priv: bytes, payload: bytes) -> bytes:
    try:
        import nacl.signing  # type: ignore

        sk = nacl.signing.SigningKey(priv)
        sig = sk.sign(payload).signature
        return bytes(sig)
    except Exception as e:  # pragma: no cover
        # Try cryptography as a fallback
        if Ed25519PrivateKey is None:
            raise
        key = Ed25519PrivateKey.from_private_bytes(priv)
        return key.sign(payload)
