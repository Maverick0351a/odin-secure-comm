from typing import Tuple

MAX_PAYLOAD_BYTES = 64 * 1024  # 64KiB for HEL-lite policy
REQUIRED_HEADERS = ("X-ODIN-Trace-Id", "X-ODIN-Payload-CID")


def check_payload_size(size: int) -> Tuple[bool, str]:
    if size <= MAX_PAYLOAD_BYTES:
        return True, "ok"
    return False, f"payload too large: {size} > {MAX_PAYLOAD_BYTES}"


def check_required_headers(headers: dict) -> Tuple[bool, str]:
    for k in REQUIRED_HEADERS:
        if k not in headers:
            return False, f"missing required header: {k}"
    return True, "ok"
