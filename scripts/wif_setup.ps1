# ODIN Secure Communication - Workload Identity Federation Setup
# This script configures Workload Identity Federation for GitHub Actions

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1",
    [string]$WifPoolId = "github-pool",
    [string]$WifProviderId = "github-provider",
    [string]$DeployerSAName = "odin-deployer",
    [string]$GitHubOrg = "Maverick0351a",
    [string]$GitHubRepo = "odin-secure-comm"
)

# Exit on any error
$ErrorActionPreference = "Stop"

Write-Host "🔐 Setting up Workload Identity Federation for GitHub Actions" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "GitHub: $GitHubOrg/$GitHubRepo" -ForegroundColor Cyan
Write-Host "WIF Pool: $WifPoolId" -ForegroundColor Cyan
Write-Host "WIF Provider: $WifProviderId" -ForegroundColor Cyan

# Create Workload Identity Pool
Write-Host "🏊 Creating Workload Identity Pool..." -ForegroundColor Yellow
$poolExists = gcloud iam workload-identity-pools describe $WifPoolId --project $ProjectId --location global --format="value(name)" 2>$null
if (-not $poolExists) {
    gcloud iam workload-identity-pools create $WifPoolId `
        --project $ProjectId `
        --location global `
        --display-name "GitHub Actions Pool for ODIN" `
        --description "Workload Identity Pool for GitHub Actions deployments"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create Workload Identity Pool" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Workload Identity Pool created successfully" -ForegroundColor Green
} else {
    Write-Host "✅ Workload Identity Pool already exists" -ForegroundColor Green
}

# Create Workload Identity Provider
Write-Host "🔗 Creating Workload Identity Provider..." -ForegroundColor Yellow
$providerExists = gcloud iam workload-identity-pools providers describe $WifProviderId --project $ProjectId --location global --workload-identity-pool $WifPoolId --format="value(name)" 2>$null
if (-not $providerExists) {
    gcloud iam workload-identity-pools providers create-oidc $WifProviderId `
        --project $ProjectId `
        --location global `
        --workload-identity-pool $WifPoolId `
        --display-name "GitHub Actions Provider" `
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.ref=assertion.ref" `
        --issuer-uri "https://token.actions.githubusercontent.com"
        
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create Workload Identity Provider" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Workload Identity Provider created successfully" -ForegroundColor Green
} else {
    Write-Host "✅ Workload Identity Provider already exists" -ForegroundColor Green
}

# Bind Service Account to Workload Identity
Write-Host "🔗 Binding Service Account to Workload Identity..." -ForegroundColor Yellow
$deployerSA = "$DeployerSAName@$ProjectId.iam.gserviceaccount.com"
$principalSet = "principalSet://iam.googleapis.com/projects/$((gcloud projects describe $ProjectId --format='value(projectNumber)'))/locations/global/workloadIdentityPools/$WifPoolId/attribute.repository/$GitHubOrg/$GitHubRepo"

gcloud iam service-accounts add-iam-policy-binding $deployerSA `
    --project $ProjectId `
    --role "roles/iam.workloadIdentityUser" `
    --member "$principalSet"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to bind Service Account to Workload Identity" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Service Account bound to Workload Identity successfully" -ForegroundColor Green

# Get project number for provider resource name
$projectNumber = gcloud projects describe $ProjectId --format="value(projectNumber)"
$wifProvider = "projects/$projectNumber/locations/global/workloadIdentityPools/$WifPoolId/providers/$WifProviderId"

Write-Host ""
Write-Host "🎉 Workload Identity Federation setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 GitHub Repository Secrets to Configure:" -ForegroundColor Cyan
Write-Host ""
Write-Host "GCP_PROJECT_ID: $ProjectId" -ForegroundColor White
Write-Host "GCP_WIF_PROVIDER: $wifProvider" -ForegroundColor White
Write-Host "GCP_DEPLOYER_SA: $deployerSA" -ForegroundColor White
Write-Host "GCP_REGION: $Region" -ForegroundColor White
Write-Host "GCP_ARTIFACT_REPO: <REPO_NAME>" -ForegroundColor White
Write-Host "GCP_SERVICE_NAME: <SERVICE_NAME>" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Setup Instructions:" -ForegroundColor Yellow
Write-Host "1. Go to GitHub repository: https://github.com/$GitHubOrg/$GitHubRepo/settings/secrets/actions" -ForegroundColor White
Write-Host "2. Add the above secrets as Repository secrets" -ForegroundColor White
Write-Host "3. Push changes to main branch to trigger GitHub Actions deployment" -ForegroundColor White
Write-Host ""
Write-Host "📋 Commands to set GitHub secrets (GitHub CLI):" -ForegroundColor Cyan
Write-Host "gh secret set GCP_PROJECT_ID --body `"$ProjectId`"" -ForegroundColor White
Write-Host "gh secret set GCP_WIF_PROVIDER --body `"$wifProvider`"" -ForegroundColor White
Write-Host "gh secret set GCP_DEPLOYER_SA --body `"$deployerSA`"" -ForegroundColor White
Write-Host "gh secret set GCP_REGION --body `"$Region`"" -ForegroundColor White
Write-Host "gh secret set GCP_ARTIFACT_REPO --body `"<REPO_NAME>`"" -ForegroundColor White
Write-Host "gh secret set GCP_SERVICE_NAME --body `"<SERVICE_NAME>`"" -ForegroundColor White
