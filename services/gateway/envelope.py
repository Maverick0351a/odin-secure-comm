from typing import Optional
from libs.odin.models import Envelope
from libs.odin.crypto import verify_ed25519


def verify_envelope(env: Envelope) -> bool:
    payload = env.payload_bytes()
    pubkey = env.sender_pubkey_bytes()
    sig = env.signature_bytes()
    return verify_ed25519(pubkey, payload, sig)
