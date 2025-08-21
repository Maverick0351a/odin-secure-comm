from dataclasses import dataclass
from .crypto import generate_keypair, b64url_no_pad

@dataclass
class KeyOML:
    kid: str
    priv: bytes
    pub: bytes

    @classmethod
    def generate(cls, kid: str = "local") -> "KeyOML":
        sk, pk = generate_keypair()
        return cls(kid=kid, priv=sk, pub=pk)

    def jwk(self) -> dict:
        return {
            "kty": "OKP",
            "crv": "Ed25519",
            "kid": self.kid,
            "use": "sig",
            "alg": "EdDSA",
            "x": b64url_no_pad(self.pub),
        }

@dataclass
class KeyReceipt(KeyOML):
    pass


# Key helpers
def key_oml(cid: str) -> str:
    return f"oml/{cid}.omlc"


def key_receipt(trace_id: str, hop_id: str) -> str:
    return f"receipts/{trace_id}/hops/{hop_id}.json"


def key_receipt_index(trace_id: str) -> str:
    return f"receipts/{trace_id}/index.json"
