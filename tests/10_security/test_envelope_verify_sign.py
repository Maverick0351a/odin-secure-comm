from libs.odin.crypto import generate_keypair, sign_ed25519, verify_ed25519, b64url_no_pad
from libs.odin.models import Envelope
from services.gateway.envelope import verify_envelope

def test_sign_and_verify_envelope():
    sk, pk = generate_keypair()
    payload = b"hello-odin"
    sig = sign_ed25519(sk, payload)
    env = Envelope.create(sender_pub=pk, payload=payload, signature=sig)
    assert verify_envelope(env) is True
    # tamper
    env_bad = Envelope.create(sender_pub=pk, payload=b"bye", signature=sig)
    assert verify_envelope(env_bad) is False
