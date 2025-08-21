# ODIN Integration Connector - Console Deployment Helper
# This script opens all necessary Google Cloud Console pages for manual deployment

param(
    [string]$ProjectId = "odin-ai-to"
)

Write-Host "ODIN Integration Connector - Console Deployment Helper" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan

# Configuration values for easy copy-paste
$config = @{
    "Project ID" = $ProjectId
    "Region" = "us-central1"
    "Connector Name" = "odin-secure-comm"
    "Display Name" = "ODIN Secure Communication"
    "Connection Name" = "odin-ai-communication"
    "Service Account" = "odin-connector-invoker@$ProjectId.iam.gserviceaccount.com"
    "Base URL" = "https://odin-gateway-583712448463.us-central1.run.app"
    "Audience" = "https://odin-gateway-583712448463.us-central1.run.app"
    "OpenAPI File" = "openapi/odin-openapi.yaml"
}

Write-Host "Configuration Values (for copy-paste):" -ForegroundColor Yellow
foreach ($key in $config.Keys) {
    Write-Host "${key}: $($config[$key])" -ForegroundColor White
}

# Console URLs
$urls = @{
    "Custom Connectors" = "https://console.cloud.google.com/integrations/connectors/custom-connectors?project=$ProjectId"
    "Connections" = "https://console.cloud.google.com/integrations/connectors/connections?project=$ProjectId"
    "Cloud Workflows" = "https://console.cloud.google.com/workflows?project=$ProjectId"
    "Cloud Run Services" = "https://console.cloud.google.com/run?project=$ProjectId"
    "IAM Service Accounts" = "https://console.cloud.google.com/iam-admin/serviceaccounts?project=$ProjectId"
}

Write-Host "Opening Google Cloud Console pages..." -ForegroundColor Yellow

# Open each URL in the default browser
foreach ($name in $urls.Keys) {
    Write-Host "Opening: $name" -ForegroundColor Cyan
    Start-Process $urls[$name]
    Start-Sleep -Seconds 2  # Delay to avoid overwhelming the browser
}

Write-Host "All console pages opened!" -ForegroundColor Green

Write-Host "Manual Deployment Steps:" -ForegroundColor Yellow
Write-Host "1. Custom Connectors → Create → Import OpenAPI → Upload openapi/odin-openapi.yaml" -ForegroundColor White
Write-Host "2. Connections → Create → Select 'ODIN Secure Communication' connector" -ForegroundColor White
Write-Host "3. Configure authentication with service account: odin-connector-invoker@$ProjectId.iam.gserviceaccount.com" -ForegroundColor White
Write-Host "4. Set base URL: https://odin-gateway-583712448463.us-central1.run.app" -ForegroundColor White
Write-Host "5. Test connection and create!" -ForegroundColor White

Write-Host "Test the deployment:" -ForegroundColor Yellow
Write-Host ".\scripts\auth-test.ps1" -ForegroundColor Cyan

Write-Host "Ready for marketplace submission!" -ForegroundColor Green
