# ODIN Protocol – AI-to-AI Secure Communication Layer

## Overview

ODIN (Open Decentralized Identity Network) is an enterprise-grade secure communication protocol designed specifically for AI-to-AI interactions. It provides cryptographically verifiable message integrity, authenticity, and audit trails using Ed25519 digital signatures and immutable receipt chains.

## Product Description

ODIN Protocol enables secure, trustworthy communication between AI agents and systems across organizational boundaries. Every message is cryptographically signed, verified, and recorded in an immutable audit trail, ensuring complete transparency and compliance for AI interactions.

### Key Features

- **Quantum-Resistant Security**: Ed25519 digital signatures provide future-proof cryptographic protection
- **Immutable Audit Trails**: Complete receipt chains for regulatory compliance and forensic analysis
- **JWKS Integration**: Industry-standard JSON Web Key Sets for seamless key management
- **RESTful API**: Simple integration with any AI system or agent framework
- **Real-time Verification**: Instant signature validation and receipt generation
- **Zero-Trust Architecture**: Every message independently verified regardless of source

## Authentication Model

ODIN Protocol requires **OIDC ID tokens** for all API calls. Authentication is handled through Google Cloud Identity-Aware Proxy (IAP) or standard OIDC providers.

### Required Headers

All API requests must include:
```
Authorization: Bearer <OIDC_ID_TOKEN>
```

For message envelope operations, additional headers are required:
```
X-ODIN-Trace-Id: <UUID>
X-ODIN-Payload-CID: <CONTENT_IDENTIFIER>
```

### Getting ID Tokens

Use Google Cloud CLI:
```bash
gcloud auth print-identity-token
```

Or configure your application to obtain ID tokens from your OIDC provider.

## Supported Regions

ODIN Protocol can be deployed in any Google Cloud region. Common deployments:

- **us-central1** (Iowa) - Primary
- **us-east1** (South Carolina) 
- **europe-west1** (Belgium)
- **asia-northeast1** (Tokyo)

## Rate Limits and Quotas

- **Message Envelope**: 1,000 requests/minute per client
- **Receipt Queries**: 5,000 requests/minute per client
- **Discovery/Health**: 10,000 requests/minute per client
- **Payload Size**: Maximum 1MB per message
- **Trace Chain**: Maximum 100 hops per trace

## Setup Instructions

### 1. Create Custom Connector

1. Navigate to **Integration Connectors** → **Custom connectors** in Google Cloud Console
2. Click **Create Custom Connector**
3. Upload the `openapi/odin-connector.yaml` file
4. Set connector name: `odin-protocol`
5. Set version: `v1`
6. Click **Create**

### 2. Configure Connection

1. Go to **Integration Connectors** → **Connections**
2. Click **Create Connection**
3. Select your custom connector: `odin-protocol`
4. Select version: `v1`
5. Configure connection settings:
   - **Connection Name**: `odin-ai-communication`
   - **Base URL**: Your ODIN Gateway URL (e.g., `https://odin-gateway-xyz.run.app`)
   - **Service Account**: Select or create service account with `roles/run.invoker`
   - **Authentication**: OAuth 2.0 (automatically configured)

### 3. Service Account Setup

Ensure your service account has the required permissions:

```bash
# Create dedicated service account
gcloud iam service-accounts create odin-connector-sa \
    --display-name="ODIN Connector Service Account"

# Grant Cloud Run invoker permission
gcloud run services add-iam-policy-binding odin-gateway \
    --member="serviceAccount:odin-connector-sa@PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/run.invoker" \
    --region=REGION
```

### 4. Test Connection

1. In the connection details page, click **Test connection**
2. Use the **Try this method** feature to test endpoints:
   - Start with `/health` to verify connectivity
   - Test `/.well-known/odin/discovery.json` for protocol info
   - Try `/v1/envelope` with sample payload

### 5. Enable Logging (Recommended)

1. In connection settings, enable **Cloud Logging**
2. Set log level to **INFO** for production, **DEBUG** for troubleshooting
3. Logs will appear in Cloud Logging under the connector resource

## Troubleshooting

### Common Issues

#### 403 Forbidden Errors
- **Cause**: Service account lacks `roles/run.invoker` permission
- **Solution**: Add IAM binding to your Cloud Run service
- **Command**: 
  ```bash
  gcloud run services add-iam-policy-binding SERVICE_NAME \
      --member="serviceAccount:SA_EMAIL" --role="roles/run.invoker"
  ```

#### Invalid Token Errors
- **Cause**: Expired or malformed ID token
- **Solution**: Refresh ID token using `gcloud auth print-identity-token`
- **Note**: ID tokens expire after 1 hour

#### CORS Errors
- **Cause**: Browser-based requests to Cloud Run service
- **Solution**: ODIN Protocol is designed for server-to-server communication
- **Alternative**: Use server-side proxy for browser-based applications

#### Connection Timeout
- **Cause**: Cold start or high latency
- **Solution**: Configure minimum instances on Cloud Run service
- **Command**:
  ```bash
  gcloud run services update SERVICE_NAME \
      --min-instances=1 --region=REGION
  ```

#### Signature Verification Failed
- **Cause**: Invalid Ed25519 signature or public key format
- **Solution**: Ensure signatures are base64-encoded and generated with Ed25519
- **Test**: Use `/health` endpoint to verify service is operational

### Getting Help

- **Documentation**: Full API documentation available in connector interface
- **Logs**: Check Cloud Logging for detailed error messages
- **Support**: Contact support@odinprotocol.dev for technical assistance
- **GitHub**: Issues and discussions at https://github.com/Maverick0351a/odin-secure-comm

### Health Check Endpoints

Use these for monitoring and troubleshooting:

- **Service Health**: `GET /health`
- **Protocol Discovery**: `GET /.well-known/odin/discovery.json`
- **Public Keys**: `GET /.well-known/jwks.json`

## Security Considerations

- Always use HTTPS endpoints
- Rotate JWKS keys regularly (recommended: monthly)
- Monitor receipt chains for unauthorized access
- Implement client-side signature verification
- Use unique trace IDs for each message flow
- Store private keys securely (Google Secret Manager recommended)

## Performance Optimization

- **Batch Operations**: Group multiple receipts queries when possible
- **Caching**: Cache JWKS responses (refresh every 24 hours)
- **Connection Pooling**: Reuse HTTP connections for multiple requests
- **Retry Logic**: Implement exponential backoff for transient failures

## Compliance Notes

ODIN Protocol is designed to support:
- **SOC 2 Type II** compliance
- **GDPR** data protection requirements  
- **HIPAA** healthcare data security
- **Financial Services** audit requirements

All receipt chains provide cryptographic proof of message integrity and non-repudiation.
