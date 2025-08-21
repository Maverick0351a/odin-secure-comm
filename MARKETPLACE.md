# Open Data Integrity Network (ODIN) — AI-to-AI Secure Communication Layer

A lightweight gateway and library set for secure, policy-enforced agent-to-agent communication.

- Repository: https://github.com/Maverick0351a/odin-secure-comm
- Documentation: This repository (README + examples)

## Click-to-Deploy

Option A: GitHub Actions (recommended)
- On push to `main`, the Deploy workflow builds and deploys to Cloud Run using Workload Identity Federation.
- Configure repo secrets:
  - `GCP_PROJECT_ID`
  - `GCP_WIF_PROVIDER` (full resource path)
  - `GCP_DEPLOYER_SA` (e.g., odin-deployer@...)

Option B: gcloud (manual)

```bash
# Build container
PROJECT_ID=<your-project>
REGION=us-central1
IMAGE=us-central1-docker.pkg.dev/$PROJECT_ID/odin/odin-gateway:$(git rev-parse --short HEAD)

gcloud auth configure-docker $REGION-docker.pkg.dev
docker build -t $IMAGE -f services/gateway/Dockerfile .
docker push $IMAGE

# Deploy Cloud Run service
SERVICE=odin-gateway

gcloud run deploy $SERVICE \
  --image $IMAGE \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 3 \
  --port 8080 \
  --set-env-vars ODIN_STORAGE=firestore,ODIN_MAX_BODY_BYTES=65536 \
  --set-secrets ODIN_JWKS_PRIV=ODIN_JWKS_PRIV:latest
```

## SLA / SLO targets (initial)

- Availability: 99.5%
- Latency: P95 for POST /v1/envelope ≤ 500 ms

## Security posture

- Workload Identity Federation only for CI/CD (no long-lived keys)
- JWKS rotation support (KID per month by default); serve active public key
- Secrets via Secret Manager (Cloud Run `--set-secrets`); no static keys in code
- Firestore-backed storage in production; in-memory for development/tests
- HEL-lite payload policy enforcement (size cap, required headers)
