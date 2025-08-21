# Setup GitHub Actions Service Account for Integration Connector Deployment

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$GitHubRepo = "Maverick0351a/odin-secure-comm"
)

Write-Host "Setting up GitHub Actions for Integration Connector deployment" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "GitHub Repo: $GitHubRepo" -ForegroundColor Cyan

# Service account for GitHub Actions
$saName = "github-actions"
$saEmail = "$saName@$ProjectId.iam.gserviceaccount.com"

Write-Host ""
Write-Host "1. Creating/updating GitHub Actions service account..." -ForegroundColor Yellow

# Create service account (if it doesn't exist)
gcloud iam service-accounts create $saName `
  --display-name="GitHub Actions" `
  --description="Service account for GitHub Actions CI/CD" `
  --project=$ProjectId 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Service account created: $saEmail" -ForegroundColor Green
} else {
    Write-Host "Service account already exists: $saEmail" -ForegroundColor Gray
}

Write-Host ""
Write-Host "2. Granting necessary IAM roles..." -ForegroundColor Yellow

$roles = @(
    "roles/connectors.admin",
    "roles/integrations.integrationInvoker", 
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/run.invoker"
)

foreach ($role in $roles) {
    Write-Host "Granting $role to $saEmail" -ForegroundColor White
    gcloud projects add-iam-policy-binding $ProjectId `
      --member="serviceAccount:$saEmail" `
      --role=$role
}

Write-Host ""
Write-Host "3. Setting up Workload Identity Federation..." -ForegroundColor Yellow

# Check if pool exists
$poolExists = gcloud iam workload-identity-pools describe github-actions-pool `
  --location=global --project=$ProjectId 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating Workload Identity Pool..." -ForegroundColor White
    gcloud iam workload-identity-pools create github-actions-pool `
      --location=global `
      --display-name="GitHub Actions Pool" `
      --description="Workload Identity Pool for GitHub Actions" `
      --project=$ProjectId
} else {
    Write-Host "Workload Identity Pool already exists" -ForegroundColor Gray
}

# Check if provider exists
$providerExists = gcloud iam workload-identity-pools providers describe github-provider `
  --workload-identity-pool=github-actions-pool `
  --location=global --project=$ProjectId 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating Workload Identity Provider..." -ForegroundColor White
    gcloud iam workload-identity-pools providers create-oidc github-provider `
      --workload-identity-pool=github-actions-pool `
      --location=global `
      --issuer-uri="https://token.actions.githubusercontent.com" `
      --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" `
      --attribute-condition="assertion.repository=='$GitHubRepo'" `
      --project=$ProjectId
} else {
    Write-Host "Workload Identity Provider already exists" -ForegroundColor Gray
}

Write-Host ""
Write-Host "4. Binding service account to Workload Identity..." -ForegroundColor Yellow
gcloud iam service-accounts add-iam-policy-binding $saEmail `
  --role="roles/iam.workloadIdentityUser" `
  --member="principalSet://iam.googleapis.com/projects/583712448463/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/$GitHubRepo" `
  --project=$ProjectId

Write-Host ""
Write-Host "5. Allowing service account to impersonate connector SA..." -ForegroundColor Yellow
gcloud iam service-accounts add-iam-policy-binding `
  odin-connector-invoker@$ProjectId.iam.gserviceaccount.com `
  --member="serviceAccount:$saEmail" `
  --role="roles/iam.serviceAccountTokenCreator" `
  --project=$ProjectId

Write-Host ""
Write-Host "Setup completed successfully!" -ForegroundColor Green

Write-Host ""
Write-Host "GitHub Actions Configuration:" -ForegroundColor Yellow
Write-Host "Workload Identity Provider: projects/583712448463/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider" -ForegroundColor White
Write-Host "Service Account: $saEmail" -ForegroundColor White

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Commit and push the workflow file" -ForegroundColor White
Write-Host "2. Go to GitHub repository Actions tab" -ForegroundColor White
Write-Host "3. Manually trigger the 'Deploy ODIN Integration Connector' workflow" -ForegroundColor White
Write-Host "4. Monitor the deployment progress" -ForegroundColor White

Write-Host ""
Write-Host "Commands to commit and push:" -ForegroundColor Cyan
Write-Host "git add .github/workflows/deploy-connector.yml" -ForegroundColor Gray
Write-Host "git commit -m 'Add GitHub Actions workflow for Integration Connector deployment'" -ForegroundColor Gray
Write-Host "git push origin main" -ForegroundColor Gray
