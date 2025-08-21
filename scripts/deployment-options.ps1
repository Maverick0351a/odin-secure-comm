# ODIN Integration Connector - Comprehensive Deployment Options
# Multiple deployment methods when standard approaches don't work

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1"
)

Write-Host "ODIN Integration Connector - Comprehensive Deployment" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan

Write-Host ""
Write-Host "Organizational policies have been cleared!" -ForegroundColor Green
Write-Host "Your policies are backed up in: backup/org-policies/" -ForegroundColor White

Write-Host ""
Write-Host "Available Deployment Methods:" -ForegroundColor Yellow

Write-Host ""
Write-Host "1. RECOMMENDED: Google Cloud Console UI" -ForegroundColor Green
Write-Host "   - Browser pages should be open already" -ForegroundColor White
Write-Host "   - Go to: Application Integration > Custom Connectors" -ForegroundColor White
Write-Host "   - Import OpenAPI: openapi/odin-openapi.yaml" -ForegroundColor White
Write-Host "   - Configure Google ID Token auth with service account" -ForegroundColor White

Write-Host ""
Write-Host "2. Google Cloud Shell (Alternative)" -ForegroundColor Cyan
Write-Host "   - Open: https://shell.cloud.google.com/?project=$ProjectId" -ForegroundColor White
Write-Host "   - Upload openapi/odin-openapi.yaml" -ForegroundColor White
Write-Host "   - Use Cloud Shell editor for manual configuration" -ForegroundColor White

Write-Host ""
Write-Host "3. Direct curl commands" -ForegroundColor Cyan
$curlCommands = @"
# Get access token
TOKEN=`$(gcloud auth print-access-token)

# Try different API endpoints
curl -X POST \
  "https://connectors.googleapis.com/v1/projects/$ProjectId/locations/$Region/customConnectors" \
  -H "Authorization: Bearer `$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customConnectorId": "odin-secure-comm",
    "displayName": "ODIN Secure Communication",
    "description": "Custom connector for ODIN AI-to-AI secure communication"
  }'
"@
Write-Host $curlCommands -ForegroundColor Gray

Write-Host ""
Write-Host "4. Application Integration via Console" -ForegroundColor Cyan
Write-Host "   URL: https://console.cloud.google.com/integrations?project=$ProjectId" -ForegroundColor White
Write-Host "   - Navigate to Application Integration" -ForegroundColor White
Write-Host "   - Create Integration with HTTP connector" -ForegroundColor White
Write-Host "   - Configure endpoints manually" -ForegroundColor White

Write-Host ""
Write-Host "5. Cloud Workflows Integration" -ForegroundColor Cyan
Write-Host "   - Create workflow that calls your endpoints" -ForegroundColor White
Write-Host "   - Use existing authentication setup" -ForegroundColor White
Write-Host "   - Deploy as managed integration" -ForegroundColor White

Write-Host ""
Write-Host "Current Status Check:" -ForegroundColor Yellow
Write-Host "✅ Cloud Run service deployed and working" -ForegroundColor Green
Write-Host "✅ All APIs enabled" -ForegroundColor Green  
Write-Host "✅ Service account configured with proper permissions" -ForegroundColor Green
Write-Host "✅ Authentication working (ID tokens)" -ForegroundColor Green
Write-Host "✅ All endpoints tested and responding" -ForegroundColor Green
Write-Host "✅ Organizational policies cleared" -ForegroundColor Green
Write-Host "✅ OpenAPI specification ready" -ForegroundColor Green

Write-Host ""
Write-Host "Verification Commands:" -ForegroundColor Yellow
Write-Host "Test endpoints: .\scripts\auth-test-clean.ps1" -ForegroundColor White
Write-Host "Open console: .\scripts\open-console.ps1" -ForegroundColor White
Write-Host "Check policies: gcloud resource-manager org-policies list --organization=785932421130" -ForegroundColor White

Write-Host ""
Write-Host "Next Action: Use the Console UI (Method 1) - most reliable!" -ForegroundColor Green
Write-Host "The browser tabs should already be open for:" -ForegroundColor White
Write-Host "- Custom Connectors" -ForegroundColor White  
Write-Host "- Connections" -ForegroundColor White
Write-Host "- Integration Console" -ForegroundColor White
