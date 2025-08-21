from services.gateway.storage.in_memory import InMemoryStorage


def test_put_get_exists_url():
    s = InMemoryStorage()
    key = "receipts/c1"
    data = b"hello"
    assert s.exists(key) is False
    s.put_bytes(key, data)
    assert s.exists(key) is True
    assert s.get_bytes(key) == data
    assert s.url_for(key).startswith("memory://")


def test_get_missing_raises():
    s = InMemoryStorage()
    try:
        s.get_bytes("missing")
        assert False, "expected FileNotFoundError"
    except FileNotFoundError:
        pass
