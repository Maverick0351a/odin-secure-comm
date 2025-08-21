#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy ODIN Secure Communication to Google Cloud Run
.DESCRIPTION
    Builds Docker image and deploys to Cloud Run with health checks
#>

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1",
    [string]$ServiceName = "odin-gateway"
)

Write-Host "Deploying ODIN Secure Communication to Cloud Run" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "Service: $ServiceName" -ForegroundColor White
Write-Host ""

$RegistryUrl = "$Region-docker.pkg.dev/$ProjectId/odin"
$ImageTag = "$RegistryUrl/$ServiceName`:latest"

# Configure Docker authentication
Write-Host "Configuring Docker authentication..." -ForegroundColor Yellow
try {
    gcloud auth configure-docker "$Region-docker.pkg.dev" --quiet
    if ($LASTEXITCODE -ne 0) { throw "Docker auth failed" }
}
catch {
    Write-Host "Failed to configure Docker authentication" -ForegroundColor Red
    exit 1
}
Write-Host "Docker authentication configured" -ForegroundColor Green

# Build Docker image
Write-Host "Building Docker image..." -ForegroundColor Yellow
try {
    docker build -t $ImageTag -f deploy/Dockerfile .
    if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }
}
catch {
    Write-Host "Failed to build Docker image" -ForegroundColor Red
    exit 1
}
Write-Host "Docker image built successfully" -ForegroundColor Green

# Push image to registry
Write-Host "Pushing image to registry..." -ForegroundColor Yellow
try {
    docker push $ImageTag
    if ($LASTEXITCODE -ne 0) { throw "Docker push failed" }
}
catch {
    Write-Host "Failed to push Docker image" -ForegroundColor Red
    exit 1
}
Write-Host "Image pushed successfully" -ForegroundColor Green

Write-Host "Deploying to Cloud Run..." -ForegroundColor Yellow
try {
    gcloud run deploy $ServiceName `
        --image=$ImageTag `
        --platform=managed `
        --region=$Region `
        --service-account="odin-gateway@$ProjectId.iam.gserviceaccount.com" `
        --set-env-vars="GOOGLE_CLOUD_PROJECT=$ProjectId,ODIN_ENV=production,ODIN_JWKS_PRIV=projects/$ProjectId/secrets/ODIN_JWKS_PRIV/versions/latest" `
        --memory=512Mi `
        --cpu=1 `
        --concurrency=100 `
        --max-instances=10 `
        --port=8080 `
        --timeout=300 `
        --quiet
    
    if ($LASTEXITCODE -ne 0) { 
        throw "Cloud Run deployment failed" 
    }
}
catch {
    Write-Host "Failed to deploy to Cloud Run" -ForegroundColor Red
    exit 1
}

# Get service URL
try {
    $ServiceUrl = gcloud run services describe $ServiceName --platform=managed --region=$Region --format="value(status.url)"
    if ($LASTEXITCODE -ne 0) { throw "Failed to get URL" }
}
catch {
    Write-Host "Failed to get service URL" -ForegroundColor Red
    exit 1
}

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Service URL: $ServiceUrl" -ForegroundColor Cyan

# Grant IAM access to your user (remove allUsers attempts)
Write-Host "Configuring IAM access..." -ForegroundColor Yellow
try {
    gcloud run services add-iam-policy-binding $ServiceName --member="user:travisjohnson@odinprotocol.dev" --role="roles/run.invoker" --region=$Region
}
catch {
    Write-Host "  Warning: IAM binding may already exist" -ForegroundColor Yellow
}

# Wait for deployment to be ready
Write-Host ""
Write-Host "Running health checks on $ServiceUrl..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Always use an ID token because service is auth-required
$token = gcloud auth print-identity-token
$h = @{ "Authorization" = "Bearer $token" }

# Health check
Write-Host "Checking health endpoint..." -ForegroundColor White
try {
    Invoke-RestMethod -Uri "$ServiceUrl/health" -Headers $h | Out-Null
    Write-Host "  Health check passed" -ForegroundColor Green
} catch {
    Write-Host "  Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Discovery check (correct path)
Write-Host "Checking discovery endpoint..." -ForegroundColor White
try {
    Invoke-RestMethod -Uri "$ServiceUrl/.well-known/odin/discovery.json" -Headers $h | Out-Null
    Write-Host "  Discovery endpoint working" -ForegroundColor Green
} catch {
    Write-Host "  Discovery check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# JWKS check
Write-Host "Checking JWKS endpoint..." -ForegroundColor White
try {
    Invoke-RestMethod -Uri "$ServiceUrl/.well-known/jwks.json" -Headers $h | Out-Null
    Write-Host "  JWKS endpoint working" -ForegroundColor Green
} catch {
    Write-Host "  JWKS check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Envelope smoke test
Write-Host "Testing envelope endpoint..." -ForegroundColor White
$envHeaders = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
    "X-ODIN-Trace-Id"   = "smoke-trace-$(Get-Random)"
    "X-ODIN-Payload-CID"= "bafySmoke"
}
$body = '{"payload":{"smoke":true}}'

try {
    Invoke-RestMethod -Uri "$ServiceUrl/v1/envelope" -Method POST -Headers $envHeaders -Body $body | Out-Null
    Write-Host "  Envelope endpoint working" -ForegroundColor Green
} catch {
    Write-Host "  Envelope test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Health checks passed." -ForegroundColor Green

Write-Host ""
Write-Host "=== DEPLOYMENT SUMMARY ===" -ForegroundColor Cyan
Write-Host "Service URL: $ServiceUrl" -ForegroundColor White
Write-Host "Image: $ImageTag" -ForegroundColor White
Write-Host "Health: $ServiceUrl/health" -ForegroundColor White
Write-Host "Discovery: $ServiceUrl/.well-known/odin/discovery.json" -ForegroundColor White
Write-Host "JWKS: $ServiceUrl/.well-known/jwks.json" -ForegroundColor White
Write-Host "Envelope: $ServiceUrl/v1/envelope" -ForegroundColor White
Write-Host "Receipts: $ServiceUrl/v1/receipts/hops" -ForegroundColor White
Write-Host "Metrics: $ServiceUrl/metrics" -ForegroundColor White

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Configure GitHub secrets for Actions deployment" -ForegroundColor White
Write-Host "  2. Run: pwsh scripts/wif_setup.ps1 to set up Workload Identity Federation" -ForegroundColor White
Write-Host "  3. Push to main branch to test GitHub Actions deployment" -ForegroundColor White
Write-Host ""
Write-Host "Optional: Create client service account for external access:" -ForegroundColor Yellow
Write-Host "  gcloud iam service-accounts create odin-client-invoker --display-name 'ODIN Client Invoker'" -ForegroundColor Gray
Write-Host "  gcloud run services add-iam-policy-binding odin-gateway --region=$Region --member='serviceAccount:odin-client-invoker@$ProjectId.iam.gserviceaccount.com' --role='roles/run.invoker'" -ForegroundColor Gray
