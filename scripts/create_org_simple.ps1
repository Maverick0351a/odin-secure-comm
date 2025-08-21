#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create ODIN project under organization
#>

param(
    [string]$NewProjectId = "odin-secure-comm-prod"
)

Write-Host "=== CREATING ORGANIZATION PROJECT ===" -ForegroundColor Green
Write-Host "New Project: $NewProjectId" -ForegroundColor White
Write-Host ""

# Find organization
Write-Host "Finding odinprotocol.dev organization..." -ForegroundColor Yellow
$orgs = gcloud organizations list --format="table(displayName,name,domain)"
Write-Host "Available organizations:" -ForegroundColor White
$orgs

$odinOrg = gcloud organizations list --filter="domain:odinprotocol.dev" --format="value(name)"
if (-not $odinOrg) {
    $odinOrg = gcloud organizations list --filter="displayName:*ODIN*" --format="value(name)"
}

if ($odinOrg) {
    Write-Host "✅ Found organization: $odinOrg" -ForegroundColor Green
} else {
    Write-Host "❌ odinprotocol.dev organization not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "ORGANIZATION SETUP REQUIRED:" -ForegroundColor Yellow
    Write-Host "1. Set up Google Workspace for odinprotocol.dev" -ForegroundColor White
    Write-Host "2. Create Google Cloud Organization" -ForegroundColor White
    Write-Host "3. Get organization admin access" -ForegroundColor White
    Write-Host ""
    Write-Host "OR continue with current individual project setup" -ForegroundColor Cyan
    exit 1
}

# Check billing
Write-Host "`nChecking billing accounts..." -ForegroundColor Yellow
$billingAccounts = gcloud billing accounts list --format="table(displayName,name,open)"
$billingAccounts

$openBilling = gcloud billing accounts list --filter="open:true" --format="value(name)" | Select-Object -First 1
if ($openBilling) {
    Write-Host "✅ Using billing: $openBilling" -ForegroundColor Green
} else {
    Write-Host "❌ No billing account found" -ForegroundColor Red
    exit 1
}

# Create project
Write-Host "`nCreating project..." -ForegroundColor Yellow
gcloud projects create $NewProjectId --organization=$odinOrg --name="ODIN Secure Communication"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Project created!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Project may already exist" -ForegroundColor Yellow
}

# Link billing
Write-Host "`nLinking billing..." -ForegroundColor Yellow
gcloud billing projects link $NewProjectId --billing-account=$openBilling

# Set active
Write-Host "`nSetting active project..." -ForegroundColor Yellow
gcloud config set project $NewProjectId

Write-Host "`n✅ ORGANIZATION PROJECT READY!" -ForegroundColor Green
Write-Host "Project: $NewProjectId" -ForegroundColor White
Write-Host "Organization: $odinOrg" -ForegroundColor White
Write-Host ""
Write-Host "Next: Run setup scripts with new project" -ForegroundColor Cyan
