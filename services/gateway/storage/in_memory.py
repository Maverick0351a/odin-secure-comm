class InMemoryStorage:
    def __init__(self, base_url: str = "memory://"):
        self._s = {}
        self.base_url = base_url

    def put_bytes(self, k: str, b: bytes) -> None:
        self._s[k] = b

    def get_bytes(self, k: str) -> bytes:
        if k not in self._s:
            raise FileNotFoundError(k)
        return self._s[k]

    def exists(self, k: str) -> bool:
        return k in self._s

    def url_for(self, k: str) -> str:
        return f"{self.base_url}{k}"
