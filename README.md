# Odin Secure Comm

A foundation for an AI-to-AI secure communication layer. This repo sets up a gateway service, crypto/keys libs, storage abstractions, tests layout, CI, and deployment stubs.

## Status

Layer 1 scaffold created. Core features (envelopes, receipts, HEL policy, metrics) are stubbed for incremental implementation.

## Quick start

- Requirements: Python 3.11+, PowerShell (Windows)
- Install deps:

```powershell
python -m venv .venv ; . .venv/Scripts/Activate.ps1 ; python -m pip install --upgrade pip ; pip install -r requirements.txt
```

- Run gateway (dev):

```powershell
./scripts/dev.ps1
```

- Run tests:

```powershell
. .venv/Scripts/Activate.ps1 ; pytest -q
```

## Project layout

See directory tree for modules. Gateway is a FastAPI app exposing health, readiness, JWKS discovery, and Prometheus metrics.

## Protocol

```json
{
	"protocol": "odin/secure-comm",
	"version": "1.0.0",
	"endpoints": {
		"jwks": "/.well-known/jwks.json",
		"envelope": "/v1/envelope",
		"receipts_list": "/v1/receipts/hops",
		"receipts_chain": "/v1/receipts/hops/chain/{trace_id}"
	}
}
```

### JWKS example

```json
{ "keys": [{ "kty":"OKP","crv":"Ed25519","kid":"gw-2025-08","x":"<base64url>" }] }
```

### Envelope request example (POST /v1/envelope)

```json
{
	"payload": {"intent":"TRANSLATE","text":"hola","target_lang":"en"},
	"headers": {
		"X-ODIN-Trace-Id":"01JC...",
		"X-ODIN-Payload-CID":"bafy...",
		"X-ODIN-OPE-Proof":"base64...",
		"X-ODIN-Agent":"did:odin:client-123"
	}
}
```

### Receipt response example

```json
{
	"ok": true,
	"receipt": {
		"trace_id":"01JC...","hop_id":"0001","payload_cid":"bafy...",
		"policy":{"verdict":"allow","rules":["size<=256kb","required-headers"]},
		"signature":{"kid":"gw-2025-08","alg":"EdDSA","sig":"base64..."},
		"ts":"2025-08-21T12:34:56Z"
	}
}
```

## License

MIT. See LICENSE.
