from libs.odin.models import Receipt

def test_chain_links():
    # simple parent-chain integrity test
    r1 = Receipt(cid="c1", parent=None, signer="a")
    r2 = Receipt(cid="c2", parent="c1", signer="a")
    r3 = Receipt(cid="c3", parent="c2", signer="a")
    chain = [r1, r2, r3]
    # reconstruct by following parents
    index = {r.cid: r for r in chain}
    assert index[r3.parent].parent == r1.cid
