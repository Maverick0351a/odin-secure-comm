# ODIN Integration Connector - Deployment Checklist

## ✅ API & Permissions Setup (COMPLETED)

### APIs Enabled
- [x] connectors.googleapis.com
- [x] integrations.googleapis.com  
- [x] run.googleapis.com
- [x] iam.googleapis.com

### Service Account Setup
- [x] Service Account: `odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com`
- [x] Role: `roles/run.invoker` (for Cloud Run access)
- [x] Role: `roles/iam.serviceAccountTokenCreator` (for user impersonation)
- [x] User: `travisjohnson@odinprotocol.dev` can impersonate SA

### Authentication Testing
- [x] ID token minting with impersonation works
- [x] All endpoints responding correctly:
  - [x] `/health` → status: ok
  - [x] `/.well-known/odin/discovery.json` → protocol info
  - [x] `/.well-known/jwks.json` → Ed25519 key
  - [x] `/v1/envelope` (POST) → receipt with signature

## 🚧 Manual Console Deployment (IN PROGRESS)

### Custom Connector Creation
- [ ] Open: https://console.cloud.google.com/integrations/connectors/custom-connectors?project=odin-ai-to
- [ ] Click "Create" 
- [ ] Choose "Import OpenAPI Specification"
- [ ] Upload: `openapi/odin-openapi.yaml`
- [ ] Set Connector Name: `odin-secure-comm`
- [ ] Set Display Name: `ODIN Secure Communication`
- [ ] Configure Authentication:
  - [ ] Type: Google ID Token
  - [ ] Service Account: `odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com`
  - [ ] Audience: `https://odin-gateway-583712448463.us-central1.run.app`
- [ ] Save and Publish version v1

### Connection Creation  
- [ ] Open: https://console.cloud.google.com/integrations/connectors/connections?project=odin-ai-to
- [ ] Click "Create"
- [ ] Select Location: `us-central1`
- [ ] Select Connector: `ODIN Secure Communication` (your custom connector)
- [ ] Select Version: `v1`
- [ ] Connection Name: `odin-ai-communication`
- [ ] Configure Authentication (should inherit from connector):
  - [ ] Service Account: `odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com`
  - [ ] Audience: `https://odin-gateway-583712448463.us-central1.run.app`
- [ ] Enable Cloud Logging: Yes
- [ ] Test Connection:
  - [ ] Test `/health` endpoint
  - [ ] Test `/v1/envelope` with headers:
    - [ ] `X-ODIN-Trace-Id: test-123`
    - [ ] `X-ODIN-Payload-CID: test-456`
- [ ] Save Connection

## 📋 Configuration Values (Copy-Paste Ready)

```
Project ID: odin-ai-to
Region: us-central1
Connector Name: odin-secure-comm
Display Name: ODIN Secure Communication
Connection Name: odin-ai-communication
Service Account: odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com
Base URL: https://odin-gateway-583712448463.us-central1.run.app
Audience: https://odin-gateway-583712448463.us-central1.run.app
OpenAPI File: openapi/odin-openapi.yaml
```

## 🎯 Marketplace Submission (NEXT)

Once Custom Connector + Connection are working:

### Publish Custom Connector Form
- [ ] Open Producer Portal: https://console.cloud.google.com/partner/marketplace
- [ ] Navigate to "Publish a custom connector"
- [ ] Fill form with:
  - [ ] Producer Project ID: (your marketplace producer project)
  - [ ] Product ID: `odin-ai-to-ai-secure-comm`
  - [ ] Product Name: `ODIN AI-to-AI Secure Communication`
  - [ ] Custom Connector: Select your `odin-secure-comm` connector
  - [ ] Connection Template: Use your `odin-ai-communication` connection

### Supporting Materials (Already Created)
- [x] `docs/CONNECTOR_README.md` - Integration guide
- [x] `docs/MARKETPLACE.md` - Marketplace listing content  
- [x] `openapi/odin-openapi.yaml` - API specification
- [x] Working deployment with authentication
- [x] Test scripts for validation

## 🧪 Testing Commands

```powershell
# Test authentication and all endpoints
.\scripts\auth-test-clean.ps1

# Open console pages
.\scripts\open-console.ps1

# Deploy infrastructure (if needed)
.\scripts\deploy.ps1
```

## 📞 Support Information

- **Cloud Run Service**: https://odin-gateway-583712448463.us-central1.run.app
- **Project**: odin-ai-to
- **Service Account**: odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com
- **Repository**: https://github.com/Maverick0351a/odin-secure-comm
- **Documentation**: See `docs/` folder for detailed guides
