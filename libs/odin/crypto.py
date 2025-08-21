import base64
from typing import Tuple
import nacl.signing
import nacl.exceptions

# Helpers for Ed25519 sign/verify and CID-ish hashing


def b64url_no_pad(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def b64url_to_bytes(s: str) -> bytes:
    pad = '=' * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + pad)


def generate_keypair() -> Tuple[bytes, bytes]:
    sk = nacl.signing.SigningKey.generate()
    vk = sk.verify_key
    return bytes(sk), bytes(vk)


def sign_ed25519(privkey: bytes, message: bytes) -> bytes:
    sk = nacl.signing.SigningKey(privkey)
    signed = sk.sign(message)
    return signed.signature


def verify_ed25519(pubkey: bytes, message: bytes, signature: bytes) -> bool:
    try:
        vk = nacl.signing.VerifyKey(pubkey)
        vk.verify(message, signature)
        return True
    except nacl.exceptions.BadSignatureError:
        return False

# Minimal CID-like content address: base64url(sha256(payload)) prefixed
import hashlib

def cid_v0(data: bytes) -> str:
    h = hashlib.sha256(data).digest()
    return "sha256:" + b64url_no_pad(h)
