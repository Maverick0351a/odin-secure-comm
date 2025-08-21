# ODIN Secure Communication - Cloud Run Deployment Script
# This script builds and deploys the ODIN gateway to Google Cloud Run

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1",
    [string]$RepoName = "odin", 
    [string]$ServiceName = "odin-secure-comm"
)

# Exit on any error
$ErrorActionPreference = "Stop"

Write-Host "🚀 Deploying ODIN Secure Communication to Cloud Run" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Service: $ServiceName" -ForegroundColor Cyan

# Build image name
$IMAGE = "$Region-docker.pkg.dev/$ProjectId/$RepoName/odin-gateway:latest"
Write-Host "Image: $IMAGE" -ForegroundColor Cyan

# Configure Docker for Artifact Registry
Write-Host "🔧 Configuring Docker authentication..." -ForegroundColor Yellow
gcloud auth configure-docker "$Region-docker.pkg.dev" --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to configure Docker authentication" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Docker authentication configured" -ForegroundColor Green

# Build the Docker image
Write-Host "🔨 Building Docker image..." -ForegroundColor Yellow
docker build -t $IMAGE -f deploy/Dockerfile .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build Docker image" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Docker image built successfully" -ForegroundColor Green

# Push the image to Artifact Registry
Write-Host "📤 Pushing image to Artifact Registry..." -ForegroundColor Yellow
docker push $IMAGE
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to push Docker image" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Image pushed successfully" -ForegroundColor Green

# Deploy to Cloud Run
Write-Host "🚀 Deploying to Cloud Run..." -ForegroundColor Yellow
gcloud run deploy $ServiceName `
    --project $ProjectId `
    --region $Region `
    --image $IMAGE `
    --allow-unauthenticated `
    --service-account "odin-gateway@$ProjectId.iam.gserviceaccount.com" `
    --set-env-vars "ODIN_STORAGE=firestore,ODIN_MAX_BODY_BYTES=65536" `
    --set-secrets "ODIN_JWKS_PRIV=ODIN_JWKS_PRIV:latest" `
    --cpu 1 `
    --memory 512Mi `
    --concurrency 60 `
    --min-instances 0 `
    --max-instances 10 `
    --port 8080 `
    --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy to Cloud Run" -ForegroundColor Red
    exit 1
}

# Get the service URL
Write-Host "🔍 Getting service URL..." -ForegroundColor Yellow
$SERVICE_URL = gcloud run services describe $ServiceName --project $ProjectId --region $Region --format="value(status.url)"
if (-not $SERVICE_URL) {
    Write-Host "❌ Failed to get service URL" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Service URL: $SERVICE_URL" -ForegroundColor Cyan
Write-Host ""

# Health check
Write-Host "🏥 Running health checks..." -ForegroundColor Yellow

try {
    # Health endpoint
    Write-Host "  Checking /health..." -ForegroundColor Cyan
    $healthResponse = Invoke-RestMethod -Uri "$SERVICE_URL/health" -Method Get -TimeoutSec 30
    if ($healthResponse.ok -eq $true) {
        Write-Host "  ✅ Health check passed" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Health check failed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    # Discovery endpoint
    Write-Host "  Checking /.well-known/odin/discovery.json..." -ForegroundColor Cyan
    $discoveryResponse = Invoke-RestMethod -Uri "$SERVICE_URL/.well-known/odin/discovery.json" -Method Get -TimeoutSec 30
    if ($discoveryResponse.protocol -eq "odin/secure-comm") {
        Write-Host "  ✅ Discovery endpoint working" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Discovery endpoint returned unexpected response" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Discovery check failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    # Envelope endpoint test
    Write-Host "  Testing POST /v1/envelope..." -ForegroundColor Cyan
    $traceId = [System.Guid]::NewGuid().ToString()
    $headers = @{
        'Content-Type' = 'application/json'
        'X-ODIN-Trace-Id' = $traceId
        'X-ODIN-Payload-CID' = 'bafyDummy'
    }
    $body = '{"payload":{"test":"deployment"}}'
    $envelopeResponse = Invoke-RestMethod -Uri "$SERVICE_URL/v1/envelope" -Method Post -Headers $headers -Body $body -TimeoutSec 30
    
    if ($envelopeResponse.ok -eq $true -and $envelopeResponse.receipt.trace_id -eq $traceId) {
        Write-Host "  ✅ Envelope endpoint working" -ForegroundColor Green
        
        # Test receipt retrieval
        Write-Host "  Testing receipt retrieval..." -ForegroundColor Cyan
        $receiptsResponse = Invoke-RestMethod -Uri "$SERVICE_URL/v1/receipts/hops?trace_id=$traceId" -Method Get -TimeoutSec 30
        if ($receiptsResponse.hops.Count -gt 0) {
            Write-Host "  ✅ Receipt retrieval working" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Receipt retrieval failed" -ForegroundColor Red
        }
    } else {
        Write-Host "  ❌ Envelope endpoint failed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Envelope test failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    # Metrics endpoint
    Write-Host "  Checking /metrics..." -ForegroundColor Cyan
    $metricsResponse = Invoke-WebRequest -Uri "$SERVICE_URL/metrics" -Method Get -TimeoutSec 30
    if ($metricsResponse.Content -match "odin_http_requests_total") {
        Write-Host "  ✅ Metrics endpoint working" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Metrics endpoint missing expected metrics" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Metrics check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 Deployment and health checks completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Quick Test Commands:" -ForegroundColor Cyan
Write-Host "  Health: curl $SERVICE_URL/health" -ForegroundColor White
Write-Host "  Discovery: curl $SERVICE_URL/.well-known/odin/discovery.json" -ForegroundColor White
Write-Host "  Metrics: curl $SERVICE_URL/metrics" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Configure GitHub secrets for Actions deployment" -ForegroundColor White
Write-Host "  2. Run: pwsh scripts/wif_setup.ps1 to set up Workload Identity Federation" -ForegroundColor White
Write-Host "  3. Push to main branch to test GitHub Actions deployment" -ForegroundColor White
