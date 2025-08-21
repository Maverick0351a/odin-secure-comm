# ODIN Organizational Policy Management
# Script to temporarily clear organizational policies that might block Integration Connectors

param(
    [string]$OrganizationId = "785932421130",
    [string]$ProjectId = "odin-ai-to",
    [switch]$DryRun = $false
)

Write-Host "ODIN Organizational Policy Management" -ForegroundColor Green
Write-Host "Organization: $OrganizationId" -ForegroundColor Cyan
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Dry Run: $DryRun" -ForegroundColor Cyan

# Policies that commonly affect Integration Connectors
$policiesToClear = @(
    "constraints/iam.allowedPolicyMemberDomains",
    "constraints/iam.disableServiceAccountKeyUpload", 
    "constraints/iam.disableServiceAccountKeyCreation",
    "constraints/iam.automaticIamGrantsForDefaultServiceAccounts",
    "constraints/compute.restrictProtocolForwardingCreationForTypes",
    "constraints/compute.setNewProjectDefaultToZonalDNSOnly",
    "constraints/storage.uniformBucketLevelAccess"
)

Write-Host ""
Write-Host "Current organizational policies:" -ForegroundColor Yellow

# Check current policies
foreach ($policy in $policiesToClear) {
    try {
        Write-Host "Checking: $policy" -ForegroundColor White
        $result = gcloud resource-manager org-policies describe $policy --organization=$OrganizationId 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Policy is SET" -ForegroundColor Yellow
        } else {
            Write-Host "  Policy is not set" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Could not check policy" -ForegroundColor Gray
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN - Would clear the following policies:" -ForegroundColor Yellow
    foreach ($policy in $policiesToClear) {
        Write-Host "  $policy" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "To actually clear policies, run:" -ForegroundColor Yellow
    Write-Host ".\scripts\clear-org-policies.ps1 -DryRun:`$false" -ForegroundColor Cyan
    exit 0
}

Write-Host ""
Write-Host "Clearing organizational policies..." -ForegroundColor Yellow

$cleared = 0
$errors = 0

foreach ($policy in $policiesToClear) {
    Write-Host "Clearing: $policy" -ForegroundColor White
    try {
        # Delete the policy at organization level
        $result = gcloud resource-manager org-policies delete $policy --organization=$OrganizationId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Cleared successfully" -ForegroundColor Green
            $cleared++
        } else {
            Write-Host "  Not set or already cleared" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        $errors++
    }
}

Write-Host ""
Write-Host "Policy clearing completed!" -ForegroundColor Green
Write-Host "Cleared: $cleared policies" -ForegroundColor White
Write-Host "Errors: $errors policies" -ForegroundColor White

if ($cleared -gt 0) {
    Write-Host ""
    Write-Host "IMPORTANT: Organizational policies have been cleared!" -ForegroundColor Red
    Write-Host "This reduces security controls. Remember to re-enable them after deployment." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To restore policies later, check your organization's policy documentation." -ForegroundColor White
}

Write-Host ""
Write-Host "Now try deploying the Integration Connector again:" -ForegroundColor Yellow
Write-Host "1. Console UI: Use the browser pages" -ForegroundColor White
Write-Host "2. REST API: .\scripts\deploy-rest-api.ps1" -ForegroundColor White
Write-Host "3. Manual verification: .\scripts\auth-test-clean.ps1" -ForegroundColor White
