from .base import Storage
from .in_memory import InMemoryStorage
try:
	from .firestore import FirestoreStorage  # type: ignore
except Exception:  # pragma: no cover - optional dependency
	FirestoreStorage = None  # type: ignore

__all__ = ["Storage", "InMemoryStorage", "FirestoreStorage"]
