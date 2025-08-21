from typing import List
try:
    from google.cloud import firestore  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    firestore = None

from libs.odin.models import Receipt

class FirestoreStorage:
    def __init__(self, project: str, collection: str = "receipts") -> None:
        if firestore is None:
            raise RuntimeError("google-cloud-firestore not installed")
        self._db = firestore.Client(project=project)
        self._col = collection

    async def write_receipt(self, receipt: Receipt) -> None:
        doc_ref = self._db.collection(self._col).document(receipt.cid)
        doc_ref.set(receipt.model_dump())

    async def list_receipts(self) -> List[Receipt]:
        docs = self._db.collection(self._col).stream()
        return [Receipt(**d.to_dict()) for d in docs]
