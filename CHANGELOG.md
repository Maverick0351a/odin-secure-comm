# Changelog

All notable changes to this project will be documented in this file.

## [0.1.1] - 2025-08-21
- Firestore storage driver (prod) with JSON-text values
- Real signing + JWKS exposure (Ed25519, kid rotation support)
- Cloud Run CI/CD via Workload Identity Federation
- Optional CORS and JSON logging with redaction

## [0.1.0] - 2025-08-21
- Initial scaffold: FastAPI gateway, HEL-lite policy, metrics, in-memory storage
- Envelope endpoint and receipts listing/chain
- Tests, CI, deploy stubs

## Roadmap

- 0.2.0 — Basic OpenAPI docs (/docs) and signed receipt schema v1 (stable)
- 1.0.0 — Production pin; Marketplace doc bundle final
