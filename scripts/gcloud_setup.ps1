# ODIN Secure Communication - GCP Setup Script
# This script sets up the necessary GCP resources for deployment

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1",
    [string]$RepoName = "odin",
    [string]$ServiceName = "odin-secure-comm",
    [string]$DeployerSAName = "odin-deployer"
)

# Exit on any error
$ErrorActionPreference = "Stop"

Write-Host "Setting up GCP resources for ODIN Secure Communication" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Artifact Registry: $RepoName" -ForegroundColor Cyan
Write-Host "Service: $ServiceName" -ForegroundColor Cyan

# Check if gcloud is authenticated
Write-Host "Checking gcloud authentication..." -ForegroundColor Yellow
try {
    $currentAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
    if (-not $currentAccount) {
        Write-Host "No active gcloud authentication found." -ForegroundColor Red
        Write-Host "Please run: gcloud auth login" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Authenticated as: $currentAccount" -ForegroundColor Green
} catch {
    Write-Host "gcloud CLI not found or not authenticated." -ForegroundColor Red
    Write-Host "Please install gcloud CLI and run: gcloud auth login" -ForegroundColor Yellow
    exit 1
}

# Set project and region
Write-Host "Setting project and region..." -ForegroundColor Yellow
gcloud config set project $ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set project. Please check project ID." -ForegroundColor Red
    exit 1
}

gcloud config set compute/region $Region
gcloud config set run/region $Region

# Enable required APIs
Write-Host "Enabling required APIs..." -ForegroundColor Yellow
$apis = @(
    "run.googleapis.com",
    "artifactregistry.googleapis.com", 
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudbuild.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "  Enabling $api..." -ForegroundColor Cyan
    gcloud services enable $api --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to enable $api" -ForegroundColor Red
        exit 1
    }
}
Write-Host "✅ All APIs enabled successfully" -ForegroundColor Green

# Create Artifact Registry repository
Write-Host "📦 Creating Artifact Registry repository..." -ForegroundColor Yellow
$repoExists = gcloud artifacts repositories describe $RepoName --location=$Region --format="value(name)" 2>$null
if (-not $repoExists) {
    gcloud artifacts repositories create $RepoName `
        --repository-format=docker `
        --location=$Region `
        --description="ODIN Secure Communication container registry"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create Artifact Registry repository" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Artifact Registry repository created: $Region-docker.pkg.dev/$ProjectId/$RepoName" -ForegroundColor Green
} else {
    Write-Host "✅ Artifact Registry repository already exists" -ForegroundColor Green
}

# Initialize Firestore
Write-Host "🔥 Initializing Firestore..." -ForegroundColor Yellow
$firestoreExists = gcloud firestore databases list --format="value(name)" 2>$null
if (-not $firestoreExists) {
    gcloud firestore databases create --location=$Region --type=firestore-native --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create Firestore database" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Firestore database created successfully" -ForegroundColor Green
} else {
    Write-Host "✅ Firestore database already exists" -ForegroundColor Green
}

# Create deployer service account
Write-Host "👤 Creating deployer service account..." -ForegroundColor Yellow
$deployerSA = "$DeployerSAName@$ProjectId.iam.gserviceaccount.com"
$saExists = gcloud iam service-accounts describe $deployerSA --format="value(email)" 2>$null
if (-not $saExists) {
    gcloud iam service-accounts create $DeployerSAName `
        --display-name="ODIN Deployer Service Account" `
        --description="Service account for deploying ODIN services"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create deployer service account" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Deployer service account created: $deployerSA" -ForegroundColor Green
} else {
    Write-Host "✅ Deployer service account already exists: $deployerSA" -ForegroundColor Green
}

# Grant roles to deployer SA
Write-Host "🔐 Granting roles to deployer service account..." -ForegroundColor Yellow
$deployerRoles = @(
    "roles/run.admin",
    "roles/artifactregistry.writer", 
    "roles/iam.serviceAccountTokenCreator",
    "roles/secretmanager.secretAccessor"
)

foreach ($role in $deployerRoles) {
    Write-Host "  Granting $role..." -ForegroundColor Cyan
    gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$deployerSA" `
        --role="$role" `
        --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Warning: Failed to grant $role to deployer SA" -ForegroundColor Yellow
    }
}

# Create runtime service account for the gateway
Write-Host "👤 Creating runtime service account..." -ForegroundColor Yellow
$runtimeSA = "odin-gateway@$ProjectId.iam.gserviceaccount.com"
$runtimeSAExists = gcloud iam service-accounts describe $runtimeSA --format="value(email)" 2>$null
if (-not $runtimeSAExists) {
    gcloud iam service-accounts create odin-gateway `
        --display-name="ODIN Gateway Runtime Service Account" `
        --description="Service account for ODIN Gateway runtime"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create runtime service account" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Runtime service account created: $runtimeSA" -ForegroundColor Green
} else {
    Write-Host "✅ Runtime service account already exists: $runtimeSA" -ForegroundColor Green
}

# Grant roles to runtime SA
Write-Host "🔐 Granting roles to runtime service account..." -ForegroundColor Yellow
$runtimeRoles = @(
    "roles/secretmanager.secretAccessor",
    "roles/datastore.user",
    "roles/monitoring.metricWriter"
)

foreach ($role in $runtimeRoles) {
    Write-Host "  Granting $role..." -ForegroundColor Cyan
    gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$runtimeSA" `
        --role="$role" `
        --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Warning: Failed to grant $role to runtime SA" -ForegroundColor Yellow
    }
}

# Create or update JWKS private key secret
Write-Host "Setting up JWKS private key..." -ForegroundColor Yellow
$secretExists = gcloud secrets describe ODIN_JWKS_PRIV --format="value(name)" 2>$null

# Generate a temporary Ed25519 key if none exists
$tempKeyPath = "temp_ed25519_key.pem"
if (-not (Test-Path $tempKeyPath)) {
    Write-Host "  Generating temporary Ed25519 key..." -ForegroundColor Cyan
    # Generate using OpenSSL if available, otherwise create a simple one
    try {
        openssl genpkey -algorithm Ed25519 -out $tempKeyPath 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "OpenSSL failed"
        }
    } catch {
        # Fallback: create a dummy key file with instruction
        @"
# This is a placeholder Ed25519 private key
# Replace this with a real Ed25519 private key in PEM format
# You can generate one with: openssl genpkey -algorithm Ed25519 -out key.pem
# Or use any 32-byte random seed
REPLACE_WITH_REAL_ED25519_KEY
"@ | Out-File -FilePath $tempKeyPath -Encoding UTF8
        Write-Host "  ⚠️  Created placeholder key file. Please replace with real Ed25519 key." -ForegroundColor Yellow
    }
}

if (-not $secretExists) {
    gcloud secrets create ODIN_JWKS_PRIV --data-file="$tempKeyPath"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create secret" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Secret ODIN_JWKS_PRIV created" -ForegroundColor Green
} else {
    Write-Host "✅ Secret ODIN_JWKS_PRIV already exists" -ForegroundColor Green
    Write-Host "  To update: gcloud secrets versions add ODIN_JWKS_PRIV --data-file=your_key.pem" -ForegroundColor Cyan
}

# Clean up temporary key file
if (Test-Path $tempKeyPath) {
    Remove-Item $tempKeyPath -Force
}

Write-Host ""
Write-Host "🎉 GCP setup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "  Project: $ProjectId" -ForegroundColor White
Write-Host "  Region: $Region" -ForegroundColor White
Write-Host "  Artifact Registry: $Region-docker.pkg.dev/$ProjectId/$RepoName" -ForegroundColor White
Write-Host "  Deployer SA: $deployerSA" -ForegroundColor White
Write-Host "  Runtime SA: $runtimeSA" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: pwsh scripts/deploy_cloudrun.ps1" -ForegroundColor White
Write-Host "  2. Configure GitHub secrets for Actions" -ForegroundColor White
Write-Host "  3. Push to main branch to trigger deployment" -ForegroundColor White
