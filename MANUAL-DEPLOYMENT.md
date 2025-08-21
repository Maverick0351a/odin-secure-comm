# ODIN Integration Connector - Manual Deployment Guide

## 🚀 **Ready to Deploy to Google Cloud Marketplace!**

Since the Integration Connectors API is relatively new and not fully supported via CLI/Terraform in all regions, we'll use the Google Cloud Console UI for the custom connector creation.

### **✅ Already Completed**
- ✅ Project: `odin-ai-to`
- ✅ Cloud Run: `https://odin-gateway-583712448463.us-central1.run.app`
- ✅ Service Account: `odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com`
- ✅ APIs Enabled: All required APIs active
- ✅ Endpoints Tested: All working perfectly

### **🎯 Manual Deployment Steps**

#### **Step 1: Create Custom Connector (5 minutes)**

1. **Open Google Cloud Console**
   - Go to: https://console.cloud.google.com/integrations/connectors/custom-connectors?project=odin-ai-to
   - Make sure you're in project `odin-ai-to`

2. **Create Custom Connector**
   - Click **"Create Custom Connector"**
   - Choose **"Import OpenAPI specification"**

3. **Upload OpenAPI Spec**
   - Click **"Upload file"**
   - Select: `openapi/odin-openapi.yaml` from your project
   - **Connector Name**: `odin-secure-comm`
   - **Display Name**: `ODIN Secure Communication`
   - **Description**: `AI-to-AI secure communication with Ed25519 signatures and cryptographic receipts`

4. **Configure Connector**
   - **Location**: `us-central1`
   - **Authentication Type**: Leave as configured in OpenAPI (Bearer Token)
   - Click **"Create"**

#### **Step 2: Create Connection (5 minutes)**

1. **Navigate to Connections**
   - Go to: https://console.cloud.google.com/integrations/connectors/connections?project=odin-ai-to
   - Click **"Create Connection"**

2. **Select Connector**
   - Choose your custom connector: **"ODIN Secure Communication"**
   - **Connection Name**: `odin-ai-communication`
   - **Location**: `us-central1`

3. **Configure Authentication**
   - **Authentication Type**: Select "Google ID Token" or "Service Account"
   - **Service Account**: `odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com`
   - **Audience**: `https://odin-gateway-583712448463.us-central1.run.app`

4. **Configure Endpoints**
   - **Base URL**: `https://odin-gateway-583712448463.us-central1.run.app`
   - Verify all endpoints are accessible

5. **Test Connection**
   - Click **"Test Connection"**
   - Verify the health endpoint responds successfully
   - Click **"Create"**

#### **Step 3: Test Integration (10 minutes)**

1. **Create Test Workflow**
   - Go to Cloud Workflows: https://console.cloud.google.com/workflows?project=odin-ai-to
   - Create a simple workflow that calls your ODIN connector

2. **Test Endpoints**
   - Use the VS Code REST Client: `.vscode/odin.http`
   - Or run: `.\scripts\simple-test.ps1`

### **📋 Ready-to-Use Configuration Values**

```yaml
# For Copy-Paste in Google Cloud Console
Project ID: odin-ai-to
Region: us-central1
Connector Name: odin-secure-comm
Display Name: ODIN Secure Communication
Connection Name: odin-ai-communication
Service Account: odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com
Base URL: https://odin-gateway-583712448463.us-central1.run.app
Audience: https://odin-gateway-583712448463.us-central1.run.app
```

### **🔗 Direct Links for Deployment**

1. **Custom Connectors**: https://console.cloud.google.com/integrations/connectors/custom-connectors?project=odin-ai-to
2. **Connections**: https://console.cloud.google.com/integrations/connectors/connections?project=odin-ai-to  
3. **Workflows**: https://console.cloud.google.com/workflows?project=odin-ai-to
4. **Cloud Run Services**: https://console.cloud.google.com/run?project=odin-ai-to

### **📦 Files for Upload**

- **OpenAPI Spec**: `openapi/odin-openapi.yaml` (ready for upload)
- **Enhanced Spec**: `openapi/odin-connector.yaml` (alternative with detailed schemas)
- **Documentation**: `marketplace/integration-connectors.md`

### **🧪 Testing Commands**

```powershell
# Test all endpoints
.\scripts\simple-test.ps1

# Generate new ID token
gcloud auth print-identity-token

# Manual curl test
$token = gcloud auth print-identity-token
curl -H "Authorization: Bearer $token" "https://odin-gateway-583712448463.us-central1.run.app/health"
```

### **📈 Marketplace Submission**

Once the connector is created and tested:

1. **Document Integration**: Use the test results and screenshots
2. **Submit to Marketplace**: Use the materials in `/marketplace/` folder
3. **Reference Architecture**: Include the deployment guide and configuration

---

## **🎊 Your ODIN Protocol is Ready for Google Cloud Marketplace!**

All infrastructure is deployed, endpoints are working, and documentation is complete. The manual UI deployment takes about 15 minutes total.

**Next**: Follow the steps above to create your custom connector and connection! 🚀
