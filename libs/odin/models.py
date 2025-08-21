from typing import Optional
from pydantic import BaseModel
from .crypto import b64url_to_bytes, b64url_no_pad, cid_v0

class Envelope(BaseModel):
    sender_pub: str  # b64url
    payload: str     # b64url
    signature: str   # b64url

    def payload_bytes(self) -> bytes:
        return b64url_to_bytes(self.payload)

    def sender_pubkey_bytes(self) -> bytes:
        return b64url_to_bytes(self.sender_pub)

    def signature_bytes(self) -> bytes:
        return b64url_to_bytes(self.signature)

    @classmethod
    def create(cls, sender_pub: bytes, payload: bytes, signature: bytes) -> "Envelope":
        return cls(
            sender_pub=b64url_no_pad(sender_pub),
            payload=b64url_no_pad(payload),
            signature=b64url_no_pad(signature),
        )

class Receipt(BaseModel):
    cid: str
    parent: Optional[str] = None
    signer: str

    @classmethod
    def from_payload(cls, payload: bytes, signer_pub: bytes, parent: Optional[str] = None) -> "Receipt":
        c = cid_v0(payload)
        return cls(cid=c, parent=parent, signer=b64url_no_pad(signer_pub))
