# ODIN Secure Communication Gateway

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Cloud Run](https://img.shields.io/badge/Deploy-Google%20Cloud%20Run-4285F4)](https://cloud.google.com/run)
[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=flat&logo=fastapi)](https://fastapi.tiangolo.com)

A production-ready secure communication layer for AI-to-AI interactions built on the Open Data Integrity Network (ODIN) protocol. This gateway service provides cryptographic receipts, policy enforcement, and verifiable audit trails for AI communications.

## 🚀 Features

- **🔐 Cryptographic Receipts**: Ed25519 signatures with JWKS discovery
- **📋 Policy Enforcement**: HEL (Header Enforcement Layer) with size and header validation
- **🔍 Audit Trails**: Complete chain reconstruction with receipt verification
- **📊 Observability**: Prometheus metrics and structured JSON logging
- **☁️ Cloud Native**: Containerized deployment to Google Cloud Run
- **🔄 CI/CD Ready**: GitHub Actions with Workload Identity Federation
- **🏗️ Production Ready**: Multi-stage Docker builds, health checks, auto-scaling

## 📋 Prerequisites

- **Python 3.11+**
- **Google Cloud SDK** (`gcloud` CLI authenticated)
- **Docker Desktop**
- **PowerShell** (Windows) or **bash** (Linux/Mac)

## ⚡ Quick Start

### 1. Local Development

```powershell
# Clone and setup
git clone https://github.com/Maverick0351a/odin-secure-comm.git
cd odin-secure-comm

# Create virtual environment and install dependencies
python -m venv .venv
. .venv/Scripts/Activate.ps1
pip install --upgrade pip
pip install -r requirements.txt

# Run tests
pytest -v

# Start development server
./scripts/dev.ps1
```

The gateway will be available at `http://localhost:8000`

### 2. Test Core Endpoints

```powershell
# Health check
Invoke-RestMethod http://localhost:8000/health

# Protocol discovery
Invoke-RestMethod http://localhost:8000/.well-known/odin/discovery.json

# Submit envelope with cryptographic receipt
$headers = @{
    'Content-Type' = 'application/json'
    'X-ODIN-Trace-Id' = [guid]::NewGuid().ToString()
    'X-ODIN-Payload-CID' = 'bafyTestPayload'
}
$body = '{"payload":{"message":"Hello ODIN"}}'
Invoke-RestMethod -Method POST -Uri http://localhost:8000/v1/envelope -Headers $headers -Body $body
```

## ☁️ Cloud Deployment

### One-Command Deployment

```powershell
# Setup GCP resources (run once)
./scripts/setup_simple.ps1

# Deploy to Cloud Run
./scripts/deploy_clean.ps1
```

This creates:
- **Artifact Registry** repository for container images
- **Firestore** database for persistent receipt storage
- **Secret Manager** for JWKS private keys
- **Service Accounts** with least-privilege IAM
- **Cloud Run** service with auto-scaling and health checks

### GitHub Actions CI/CD

```powershell
# Setup Workload Identity Federation
./scripts/wif_setup.ps1

# Add these secrets to your GitHub repository:
# - GCP_PROJECT_ID: your-project-id
# - GCP_WIF_PROVIDER: (output from wif_setup.ps1)
# - GCP_DEPLOYER_SA: (output from wif_setup.ps1)
```

Push to `main` branch triggers automatic deployment!

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AI Client A   │───▶│  ODIN Gateway    │───▶│   AI Client B   │
└─────────────────┘    │                  │    └─────────────────┘
                       │  • Policy Check  │
                       │  • Sign Receipt  │
                       │  • Store Audit   │
                       └──────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  Cloud Firestore │
                       │  (Receipt Store)  │
                       └──────────────────┘
```

### Core Components

- **Gateway Service**: FastAPI application with protocol endpoints
- **Crypto Layer**: Ed25519 signing with JWKS key rotation
- **Storage Layer**: Pluggable backends (Memory/Firestore)
- **Policy Engine**: HEL-lite enforcement (headers + size limits)
- **Metrics**: Prometheus instrumentation for observability

## 📡 API Reference

### Protocol Discovery
```http
GET /.well-known/odin/discovery.json
```

### JWKS (Public Keys)
```http
GET /.well-known/jwks.json
```

### Submit Envelope
```http
POST /v1/envelope
Content-Type: application/json
X-ODIN-Trace-Id: {unique-trace-id}
X-ODIN-Payload-CID: {content-identifier}

{
  "payload": {
    "intent": "TRANSLATE",
    "text": "Hello world",
    "target_lang": "es"
  }
}
```

### Retrieve Receipts
```http
GET /v1/receipts/hops?trace_id={trace-id}
GET /v1/receipts/hops/chain/{trace-id}
```

### Health & Metrics
```http
GET /health
GET /metrics
```

## 🔒 Security

- **Ed25519 Signatures**: All receipts cryptographically signed
- **No Static Keys**: WIF-based authentication for CI/CD
- **Least Privilege**: Service accounts with minimal required permissions
- **Policy Enforcement**: Configurable size limits and header requirements
- **Audit Trails**: Immutable receipt chains for verification

## 🛠️ Configuration

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `ODIN_STORAGE` | Storage backend (`memory`/`firestore`) | `memory` |
| `ODIN_MAX_BODY_BYTES` | Maximum payload size | `65536` |
| `ODIN_JWKS_PRIV` | Private key for signing (Secret Manager path) | Generated |
| `ODIN_LOG_LEVEL` | Logging verbosity | `INFO` |
| `GOOGLE_CLOUD_PROJECT` | GCP project for Firestore | Auto-detected |

## 🧪 Testing

```powershell
# Run all tests
pytest -v

# Run specific test categories
pytest tests/00_smoke/ -v        # Health and discovery
pytest tests/10_security/ -v     # Cryptographic verification
pytest tests/20_receipts/ -v     # Receipt storage and retrieval
pytest tests/30_policy/ -v       # Policy enforcement
pytest tests/40_metrics/ -v      # Prometheus metrics
```

## 📊 Monitoring

The gateway exposes Prometheus metrics at `/metrics`:

- `odin_http_requests_total` - Request counts by method/path/status
- `odin_requests_total` - Legacy request counter
- `odin_gateway_requests_total` - Gateway-specific metrics

Integrate with your monitoring stack (Grafana, DataDog, etc.) for observability.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [ODIN Protocol Specification](https://docs.odinprotocol.dev)
- [Marketplace Overview](MARKETPLACE.md)
- [Changelog](CHANGELOG.md)
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)

---

**Built with ❤️ by the ODIN Protocol team**
