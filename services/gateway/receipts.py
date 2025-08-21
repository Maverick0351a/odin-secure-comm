from typing import Optional, List
from libs.odin.models import Receipt

# Placeholder in-memory receipt store; will be replaced by storage backend.
_RECEIPTS: List[Receipt] = []


def store_receipt(r: Receipt) -> None:
    _RECEIPTS.append(r)


def list_receipts() -> List[Receipt]:
    return list(_RECEIPTS)
