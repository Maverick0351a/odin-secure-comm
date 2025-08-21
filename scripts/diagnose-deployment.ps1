# GitHub Actions Deployment Diagnostic
# Run this to check what might have failed in the GitHub Actions deployment

param(
    [string]$ProjectId = "odin-ai-to"
)

Write-Host "GitHub Actions Deployment Diagnostic" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== Checking Authentication ===" -ForegroundColor Yellow
try {
    $currentProject = gcloud config get-value project
    Write-Host "Current project: $currentProject" -ForegroundColor White
    
    $account = gcloud config get-value account
    Write-Host "Current account: $account" -ForegroundColor White
    
    if ($currentProject -ne $ProjectId) {
        Write-Host "Setting project to $ProjectId..." -ForegroundColor White
        gcloud config set project $ProjectId
    }
} catch {
    Write-Host "Authentication issue: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Checking APIs ===" -ForegroundColor Yellow
$requiredApis = @(
    "connectors.googleapis.com",
    "integrations.googleapis.com", 
    "run.googleapis.com",
    "iam.googleapis.com"
)

foreach ($api in $requiredApis) {
    try {
        $enabled = gcloud services list --enabled --filter="name:$api" --format="value(name)" 2>$null
        if ($enabled) {
            Write-Host "✅ $api - Enabled" -ForegroundColor Green
        } else {
            Write-Host "❌ $api - NOT Enabled" -ForegroundColor Red
            Write-Host "   Enable with: gcloud services enable $api" -ForegroundColor Gray
        }
    } catch {
        Write-Host "⚠️ $api - Could not check" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Checking Service Accounts ===" -ForegroundColor Yellow
$serviceAccounts = @(
    "github-actions@$ProjectId.iam.gserviceaccount.com",
    "odin-connector-invoker@$ProjectId.iam.gserviceaccount.com"
)

foreach ($sa in $serviceAccounts) {
    try {
        $exists = gcloud iam service-accounts describe $sa --project=$ProjectId 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $sa - Exists" -ForegroundColor Green
        } else {
            Write-Host "❌ $sa - Does not exist" -ForegroundColor Red
        }
    } catch {
        Write-Host "⚠️ $sa - Could not check" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Testing Cloud Run Service ===" -ForegroundColor Yellow
$baseUrl = "https://odin-gateway-583712448463.us-central1.run.app"
$serviceAccount = "odin-connector-invoker@$ProjectId.iam.gserviceaccount.com"

try {
    Write-Host "Minting ID token..." -ForegroundColor White
    $token = gcloud auth print-identity-token `
        --impersonate-service-account=$serviceAccount `
        --audiences=$baseUrl 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ID token minted successfully" -ForegroundColor Green
        
        Write-Host "Testing health endpoint..." -ForegroundColor White
        $response = Invoke-RestMethod -Uri "$baseUrl/health" -Headers @{Authorization="Bearer $token"} -ErrorAction Stop
        Write-Host "✅ Health endpoint working: $($response.status)" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to mint ID token" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Cloud Run test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Checking Workload Identity ===" -ForegroundColor Yellow
try {
    $pool = gcloud iam workload-identity-pools describe github-actions-pool `
        --location=global --project=$ProjectId --format="value(name)" 2>$null
    
    if ($pool) {
        Write-Host "✅ Workload Identity Pool exists" -ForegroundColor Green
        
        $provider = gcloud iam workload-identity-pools providers describe github-provider `
            --workload-identity-pool=github-actions-pool `
            --location=global --project=$ProjectId --format="value(name)" 2>$null
        
        if ($provider) {
            Write-Host "✅ Workload Identity Provider exists" -ForegroundColor Green
        } else {
            Write-Host "❌ Workload Identity Provider missing" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Workload Identity Pool missing" -ForegroundColor Red
    }
} catch {
    Write-Host "⚠️ Could not check Workload Identity" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Testing Connector APIs ===" -ForegroundColor Yellow
try {
    $token = gcloud auth print-access-token
    
    Write-Host "Testing connectors.googleapis.com..." -ForegroundColor White
    $response = Invoke-WebRequest -Uri "https://connectors.googleapis.com/v1/projects/$ProjectId/locations/us-central1/customConnectors" `
        -Headers @{Authorization="Bearer $token"} -ErrorAction Stop
    Write-Host "✅ Connectors API accessible (HTTP $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "❌ Connectors API test failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "   Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Common Issues & Solutions ===" -ForegroundColor Yellow
Write-Host "1. API not enabled → Run: gcloud services enable [api-name]" -ForegroundColor White
Write-Host "2. Service account missing → Run: .\scripts\setup-github-actions.ps1" -ForegroundColor White
Write-Host "3. Workload Identity issues → Check GitHub repo settings" -ForegroundColor White
Write-Host "4. Connector API not available → Use manual console deployment" -ForegroundColor White
Write-Host "5. Permission denied → Check IAM roles for service accounts" -ForegroundColor White

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. Fix any issues shown above" -ForegroundColor White
Write-Host "2. Try the simplified workflow: deploy-simple.yml" -ForegroundColor White
Write-Host "3. Use manual deployment if APIs not available" -ForegroundColor White
Write-Host "4. Check GitHub Actions logs for specific error messages" -ForegroundColor White
