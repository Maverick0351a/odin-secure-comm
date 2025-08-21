#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create a client service account for external ODIN gateway access
.DESCRIPTION
    Creates a service account that external clients can use to access the ODIN gateway
    via Workload Identity Federation (no static keys required)
#>

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1",
    [string]$ServiceName = "odin-gateway",
    [string]$ClientSaName = "odin-client-invoker"
)

Write-Host "Creating client service account for ODIN gateway access..." -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor White
Write-Host "Client SA: $ClientSaName" -ForegroundColor White
Write-Host ""

# Create client service account
Write-Host "Creating service account '$ClientSaName'..." -ForegroundColor Yellow
try {
    gcloud iam service-accounts create $ClientSaName --display-name "ODIN Client Invoker" --project=$ProjectId
    if ($LASTEXITCODE -ne 0) { 
        Write-Host "Service account may already exist, continuing..." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Warning: Service account creation failed, may already exist" -ForegroundColor Yellow
}

# Grant invoker role to the client service account
Write-Host "Granting Cloud Run invoker role..." -ForegroundColor Yellow
try {
    gcloud run services add-iam-policy-binding $ServiceName `
        --region=$Region `
        --member="serviceAccount:$ClientSaName@$ProjectId.iam.gserviceaccount.com" `
        --role="roles/run.invoker"
    
    if ($LASTEXITCODE -ne 0) { 
        throw "Failed to grant invoker role" 
    }
}
catch {
    Write-Host "Failed to grant invoker role" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== CLIENT SERVICE ACCOUNT CREATED ===" -ForegroundColor Cyan
Write-Host "Service Account: $ClientSaName@$ProjectId.iam.gserviceaccount.com" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Configure Workload Identity Federation for this service account" -ForegroundColor White
Write-Host "  2. External clients can authenticate as this SA via OIDC tokens" -ForegroundColor White
Write-Host "  3. No static service account keys required!" -ForegroundColor White
Write-Host ""
Write-Host "Example WIF configuration:" -ForegroundColor Yellow
Write-Host "  gcloud iam workload-identity-pools create-cred-config \" -ForegroundColor Gray
Write-Host "    projects/$ProjectId/locations/global/workloadIdentityPools/YOUR_POOL \" -ForegroundColor Gray
Write-Host "    --service-account=$ClientSaName@$ProjectId.iam.gserviceaccount.com \" -ForegroundColor Gray
Write-Host "    --output-file=client-credentials.json" -ForegroundColor Gray
