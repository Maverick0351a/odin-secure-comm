# ODIN Secure Communication - GCP Setup Script (Robust Version)
param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1", 
    [string]$RepoName = "odin",
    [string]$ServiceName = "odin-secure-comm",
    [string]$DeployerSAName = "odin-deployer"
)

$ErrorActionPreference = "Continue"  # Continue on non-critical errors

Write-Host "=== ODIN GCP Setup for Project: $ProjectId ===" -ForegroundColor Green

# Set project
Write-Host "Setting project to $ProjectId..." -ForegroundColor Yellow
gcloud config set project $ProjectId

# Enable APIs
Write-Host "Enabling required APIs..." -ForegroundColor Yellow
$apis = @(
    "run.googleapis.com",
    "artifactregistry.googleapis.com", 
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "Enabling $api..." -ForegroundColor Cyan
    gcloud services enable $api --quiet
}

# Create Artifact Registry repository
Write-Host "Creating Artifact Registry repository '$RepoName'..." -ForegroundColor Yellow
gcloud artifacts repositories create $RepoName `
    --repository-format=docker `
    --location=$Region `
    --description="ODIN container registry" `
    --quiet

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: Artifact Registry repository created" -ForegroundColor Green
} else {
    Write-Host "Repository may already exist or creation failed" -ForegroundColor Yellow
}

# Create Firestore database
Write-Host "Creating Firestore database..." -ForegroundColor Yellow
gcloud firestore databases create --location=$Region --type=firestore-native --quiet

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: Firestore database created" -ForegroundColor Green
} else {
    Write-Host "Firestore may already exist or creation failed" -ForegroundColor Yellow
}

# Create deployer service account
Write-Host "Creating deployer service account '$DeployerSAName'..." -ForegroundColor Yellow
gcloud iam service-accounts create $DeployerSAName `
    --display-name="ODIN Deployer" `
    --quiet

$deployerSA = "$DeployerSAName@$ProjectId.iam.gserviceaccount.com"

# Create runtime service account
Write-Host "Creating runtime service account 'odin-gateway'..." -ForegroundColor Yellow
gcloud iam service-accounts create odin-gateway `
    --display-name="ODIN Gateway Runtime" `
    --quiet

$runtimeSA = "odin-gateway@$ProjectId.iam.gserviceaccount.com"

# Grant roles to deployer SA
Write-Host "Granting roles to deployer service account..." -ForegroundColor Yellow
$deployerRoles = @(
    "roles/run.admin",
    "roles/artifactregistry.writer", 
    "roles/iam.serviceAccountTokenCreator",
    "roles/secretmanager.secretAccessor"
)

foreach ($role in $deployerRoles) {
    gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$deployerSA" `
        --role="$role" `
        --quiet
}

# Grant roles to runtime SA
Write-Host "Granting roles to runtime service account..." -ForegroundColor Yellow
$runtimeRoles = @(
    "roles/secretmanager.secretAccessor",
    "roles/datastore.user", 
    "roles/monitoring.metricWriter"
)

foreach ($role in $runtimeRoles) {
    gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$runtimeSA" `
        --role="$role" `
        --quiet
}

# Create JWKS secret
Write-Host "Creating JWKS secret..." -ForegroundColor Yellow
$tempKey = "temp_key_$(Get-Random).bin"

# Generate a 32-byte key using Python
python -c "import os; open('$tempKey', 'wb').write(os.urandom(32))"

gcloud secrets create ODIN_JWKS_PRIV --data-file="$tempKey" --quiet

# Clean up temp file
if (Test-Path $tempKey) {
    Remove-Item $tempKey -Force
}

Write-Host ""
Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor White
Write-Host "Registry: $Region-docker.pkg.dev/$ProjectId/$RepoName" -ForegroundColor White
Write-Host "Deployer SA: $deployerSA" -ForegroundColor White
Write-Host "Runtime SA: $runtimeSA" -ForegroundColor White
Write-Host ""
Write-Host "Next: Run .\scripts\deploy_cloudrun.ps1" -ForegroundColor Yellow
