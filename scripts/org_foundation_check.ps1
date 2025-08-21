Write-Host "=== GOOGLE CLOUD ORGANIZATION SETUP FOR ODINPROTOCOL.DEV ===" -ForegroundColor Green
Write-Host "Required for: Google Cloud Marketplace Producer Portal Access" -ForegroundColor Yellow
Write-Host ""

Write-Host "ORGANIZATION FOUNDATION REQUIREMENTS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Google Workspace Setup (REQUIRED)" -ForegroundColor Yellow
Write-Host "   Domain: odinprotocol.dev must be verified in Google Workspace" -ForegroundColor White
Write-Host "   Admin Account: Super Admin access required" -ForegroundColor White
Write-Host ""
Write-Host "2. Google Cloud Organization (AUTO-CREATED)" -ForegroundColor Yellow
Write-Host "   Created automatically when first Google Workspace admin accesses Cloud Console" -ForegroundColor White
Write-Host ""

Write-Host "CURRENT SITUATION ASSESSMENT:" -ForegroundColor Red
Write-Host ""

$currentUser = gcloud auth list --filter=status:ACTIVE --format="value(account)"
Write-Host "Current User: $currentUser" -ForegroundColor White

if ($currentUser -like "*odinprotocol.dev") {
    Write-Host "You are using odinprotocol.dev email" -ForegroundColor Green
    
    try {
        $hasOrg = gcloud organizations list --format="value(name)" 2>$null
        if ($hasOrg) {
            Write-Host "You have access to organizations" -ForegroundColor Green
            gcloud organizations list --format="table(displayName,name,domain)"
        } else {
            Write-Host "No organization access - Google Workspace setup needed" -ForegroundColor Red
        }
    } catch {
        Write-Host "Cannot access organizations - Google Workspace setup required" -ForegroundColor Red
    }
} else {
    Write-Host "You are not using odinprotocol.dev email" -ForegroundColor Red
    Write-Host "Switch to admin account for odinprotocol.dev" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "RECOMMENDED NEXT ACTIONS:" -ForegroundColor Cyan
Write-Host ""

if ($currentUser -like "*odinprotocol.dev") {
    Write-Host "Since you are using odinprotocol.dev:" -ForegroundColor Green
    Write-Host "1. Verify Google Workspace is set up for odinprotocol.dev domain" -ForegroundColor White
    Write-Host "2. Ensure you have Super Admin role in Workspace" -ForegroundColor White
    Write-Host "3. Access Cloud Console to trigger organization creation" -ForegroundColor White
} else {
    Write-Host "1. Set up Google Workspace for odinprotocol.dev domain" -ForegroundColor White
    Write-Host "2. Create admin account for odinprotocol.dev" -ForegroundColor White  
    Write-Host "3. Authenticate with gcloud auth login" -ForegroundColor White
}

Write-Host ""
Write-Host "HELPFUL LINKS:" -ForegroundColor Cyan
Write-Host "Google Workspace Setup: https://workspace.google.com" -ForegroundColor Blue
Write-Host "Domain Verification: https://admin.google.com" -ForegroundColor Blue
Write-Host "Cloud Console: https://console.cloud.google.com" -ForegroundColor Blue
Write-Host ""

Write-Host "AFTER ORGANIZATION IS CREATED:" -ForegroundColor Yellow
Write-Host "Run the setup_org_vpc.ps1 script to configure VPC under organization" -ForegroundColor White
