from typing import Optional

try:
    from google.cloud import firestore  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    firestore = None


class FirestoreStorage:
    """Firestore-backed key-value storage for small JSON payloads.

    - Keys are used directly as document IDs.
    - Values are stored as JSON text in a single field 'v' (UTF-8 string).
    - Keep keys simple, e.g., 'receipts/<trace_id>/hops/<hop_id>.json'.
    """

    def __init__(self, project: Optional[str] = None, collection: str = "receipts", base_url: str = "firestore://") -> None:
        if firestore is None:  # pragma: no cover - optional dependency not present in tests
            raise RuntimeError("google-cloud-firestore not installed")
        # project may be None to use default credentials/project discovery
        self._db = firestore.Client(project=project) if project else firestore.Client()
        self._col = collection
        self.base_url = base_url

    def _doc(self, key: str):
        return self._db.collection(self._col).document(key)

    def put_bytes(self, key: str, data: bytes) -> None:
        # Expect JSON payloads; store as text for safety with Firestore security rules
        text = data.decode("utf-8")
        self._doc(key).set({"v": text}, merge=False)

    def get_bytes(self, key: str) -> bytes:
        snap = self._doc(key).get()
        if not snap.exists:
            raise FileNotFoundError(key)
        doc = snap.to_dict() or {}
        v = doc.get("v")
        if v is None:
            raise FileNotFoundError(key)
        return str(v).encode("utf-8")

    def exists(self, key: str) -> bool:
        snap = self._doc(key).get()
        return bool(snap.exists)

    def url_for(self, key: str) -> str:
        return f"{self.base_url}{self._col}/{key}"
