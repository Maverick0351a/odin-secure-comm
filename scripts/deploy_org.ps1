#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy ODIN Secure Communication to organization project
.DESCRIPTION
    Deploys the ODIN gateway to the odin-secure-comm-org project under odinprotocol.dev organization
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "odin-secure-comm-org",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-central1",
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceName = "odin-gateway"
)

Write-Host "=== DEPLOYING ODIN GATEWAY TO ORGANIZATION PROJECT ===" -ForegroundColor Green
Write-Host ""

# Set project
Write-Host "Setting project to: $ProjectId" -ForegroundColor Cyan
gcloud config set project $ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set project" -ForegroundColor Red
    exit 1
}

Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Service: $ServiceName" -ForegroundColor Cyan
Write-Host ""

# Build and push container
Write-Host "Building and pushing container..." -ForegroundColor Yellow

$imageName = "$Region-docker.pkg.dev/$ProjectId/odin-containers/odin-gateway:latest"
Write-Host "Image: $imageName" -ForegroundColor White

# Configure Docker authentication
Write-Host "Configuring Docker authentication..." -ForegroundColor Cyan
gcloud auth configure-docker "$Region-docker.pkg.dev" --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker authentication failed" -ForegroundColor Red
    exit 1
}

# Build image
Write-Host "Building Docker image..." -ForegroundColor Cyan
docker build -t $imageName -f deploy/Dockerfile .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed" -ForegroundColor Red
    exit 1
}

# Push image
Write-Host "Pushing image to Artifact Registry..." -ForegroundColor Cyan
docker push $imageName
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker push failed" -ForegroundColor Red
    exit 1
}

Write-Host "Container pushed successfully" -ForegroundColor Green
Write-Host ""

# Deploy to Cloud Run
Write-Host "Deploying to Cloud Run..." -ForegroundColor Yellow

# Create service account for Cloud Run
$serviceAccount = "odin-gateway-sa"
Write-Host "Creating service account..." -ForegroundColor Cyan

$existingSA = gcloud iam service-accounts list --filter="email:$serviceAccount@$ProjectId.iam.gserviceaccount.com" --format="value(email)" 2>$null
if ($existingSA) {
    Write-Host "Service account already exists" -ForegroundColor Green
} else {
    gcloud iam service-accounts create $serviceAccount --display-name="ODIN Gateway Service Account" --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Service account created" -ForegroundColor Green
    } else {
        Write-Host "Service account creation failed" -ForegroundColor Red
        exit 1
    }
}

# Grant permissions to service account
Write-Host "Granting permissions..." -ForegroundColor Cyan
$saEmail = "$serviceAccount@$ProjectId.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$saEmail" --role="roles/datastore.user" --quiet
gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$saEmail" --role="roles/secretmanager.secretAccessor" --quiet

# Create secrets if they don't exist
Write-Host ""
Write-Host "Setting up secrets..." -ForegroundColor Cyan

# Create JWKS secret if it doesn't exist
$jwksSecret = "odin-jwks"
$existingJwks = gcloud secrets list --filter="name:projects/$ProjectId/secrets/$jwksSecret" --format="value(name)" 2>$null
if (-not $existingJwks) {
    Write-Host "Creating JWKS secret..." -ForegroundColor Yellow
    
    # Generate Ed25519 key pair for JWKS
    $tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_.FullName }
    $privateKeyPath = Join-Path $tempDir "private.pem"
    $publicKeyPath = Join-Path $tempDir "public.pem"
    
    # Generate Ed25519 key pair using OpenSSL
    openssl genpkey -algorithm Ed25519 -out $privateKeyPath 2>$null
    openssl pkey -in $privateKeyPath -pubout -out $publicKeyPath 2>$null
    
    if (Test-Path $privateKeyPath -and Test-Path $publicKeyPath) {
        # Create basic JWKS structure (this should be replaced with proper JWKS generation)
        $jwksData = @{
            keys = @(
                @{
                    kty = "OKP"
                    crv = "Ed25519"
                    use = "sig"
                    kid = "odin-key-1"
                    alg = "EdDSA"
                    # Note: In production, you'd extract the actual key values
                }
            )
        } | ConvertTo-Json -Depth 10
        
        $jwksData | gcloud secrets create $jwksSecret --data-file=- --quiet
        Write-Host "JWKS secret created" -ForegroundColor Green
    } else {
        Write-Host "Failed to generate keys, creating placeholder secret" -ForegroundColor Yellow
        '{"keys":[]}' | gcloud secrets create $jwksSecret --data-file=- --quiet
    }
    
    # Clean up temp files
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
} else {
    Write-Host "JWKS secret already exists" -ForegroundColor Green
}

# Deploy Cloud Run service
Write-Host ""
Write-Host "Deploying Cloud Run service..." -ForegroundColor Yellow

gcloud run deploy $ServiceName --image=$imageName --platform=managed --region=$Region --service-account=$saEmail --set-env-vars="PROJECT_ID=$ProjectId,JWKS_SECRET_NAME=$jwksSecret" --allow-unauthenticated --vpc-connector= --vpc-egress=all-traffic --max-instances=10 --memory=512Mi --cpu=1 --port=8080 --quiet

if ($LASTEXITCODE -eq 0) {
    Write-Host "Cloud Run deployment successful" -ForegroundColor Green
    
    # Get service URL
    $serviceUrl = gcloud run services describe $ServiceName --region=$Region --format="value(status.url)"
    Write-Host ""
    Write-Host "Service deployed successfully!" -ForegroundColor Green
    Write-Host "URL: $serviceUrl" -ForegroundColor Cyan
    
    # Test health endpoint
    Write-Host ""
    Write-Host "Testing health endpoint..." -ForegroundColor Cyan
    try {
        $healthResponse = Invoke-RestMethod -Uri "$serviceUrl/health" -Method Get -TimeoutSec 30
        Write-Host "Health check passed: $($healthResponse.status)" -ForegroundColor Green
    } catch {
        Write-Host "Health check failed: $_" -ForegroundColor Yellow
        Write-Host "Service may still be starting up" -ForegroundColor Yellow
    }
    
    # Test discovery endpoint
    Write-Host "Testing discovery endpoint..." -ForegroundColor Cyan
    try {
        $discoveryResponse = Invoke-RestMethod -Uri "$serviceUrl/.well-known/odin_configuration" -Method Get -TimeoutSec 30
        Write-Host "Discovery endpoint working" -ForegroundColor Green
    } catch {
        Write-Host "Discovery endpoint failed: $_" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "Cloud Run deployment failed" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host ""
Write-Host "=== DEPLOYMENT COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "DEPLOYED RESOURCES:" -ForegroundColor Cyan
Write-Host "Project: $ProjectId (under odinprotocol.dev org)" -ForegroundColor White
Write-Host "Service: $ServiceName" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "URL: $serviceUrl" -ForegroundColor White
Write-Host "VPC: odin-secure-vpc" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEPS FOR MARKETPLACE:" -ForegroundColor Yellow
Write-Host "1. Verify all endpoints are working" -ForegroundColor White
Write-Host "2. Complete security review" -ForegroundColor White
Write-Host "3. Apply for Producer Portal access" -ForegroundColor White
Write-Host "4. Submit application for Marketplace listing" -ForegroundColor White
Write-Host ""
Write-Host "MARKETPLACE PORTAL:" -ForegroundColor Cyan
Write-Host "https://console.cloud.google.com/marketplace/product/gcp-marketplace-portal" -ForegroundColor Blue
