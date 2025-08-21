#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup guide for odinprotocol.dev Google Cloud Organization
.DESCRIPTION
    Step-by-step guide to create the organization foundation required for Marketplace Producer Portal
#>

Write-Host "=== GOOGLE CLOUD ORGANIZATION SETUP FOR ODINPROTOCOL.DEV ===" -ForegroundColor Green
Write-Host "Required for: Google Cloud Marketplace Producer Portal Access" -ForegroundColor Yellow
Write-Host ""

Write-Host "🏢 ORGANIZATION FOUNDATION REQUIREMENTS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Google Workspace Setup (REQUIRED)" -ForegroundColor Yellow
Write-Host "   • Domain: odinprotocol.dev must be verified in Google Workspace" -ForegroundColor White
Write-Host "   • Admin Account: Super Admin access required" -ForegroundColor White
Write-Host "   • Billing: Google Workspace subscription active" -ForegroundColor White
Write-Host ""
Write-Host "2. Google Cloud Organization (AUTO-CREATED)" -ForegroundColor Yellow
Write-Host "   • Created automatically when first Google Workspace admin accesses Cloud Console" -ForegroundColor White
Write-Host "   • Links to odinprotocol.dev domain" -ForegroundColor White
Write-Host "   • Provides organization-level resource management" -ForegroundColor White
Write-Host ""

Write-Host "📋 STEP-BY-STEP SETUP PROCESS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "STEP 1: Google Workspace Setup" -ForegroundColor Yellow
Write-Host "1. Go to: https://workspace.google.com" -ForegroundColor Blue
Write-Host "2. Sign up for Google Workspace with domain: odinprotocol.dev" -ForegroundColor White
Write-Host "3. Verify domain ownership (DNS verification)" -ForegroundColor White
Write-Host "4. Complete Google Workspace admin setup" -ForegroundColor White
Write-Host "5. Ensure you have Super Admin role" -ForegroundColor White
Write-Host ""

Write-Host "STEP 2: Access Google Cloud Console" -ForegroundColor Yellow
Write-Host "1. Go to: https://console.cloud.google.com" -ForegroundColor Blue
Write-Host "2. Sign in with your odinprotocol.dev admin account" -ForegroundColor White
Write-Host "3. Accept Google Cloud terms (triggers organization creation)" -ForegroundColor White
Write-Host "4. Organization will be automatically created for odinprotocol.dev" -ForegroundColor White
Write-Host ""

Write-Host "STEP 3: Verify Organization Creation" -ForegroundColor Yellow
Write-Host "1. In Cloud Console, go to: IAM and Admin > Manage Resources" -ForegroundColor White
Write-Host "2. You should see organization: odinprotocol.dev" -ForegroundColor White
Write-Host "3. Note the Organization ID (numbers)" -ForegroundColor White
Write-Host ""

Write-Host "STEP 4: Create Organization Project" -ForegroundColor Yellow
Write-Host "1. Create new project under the organization" -ForegroundColor White
Write-Host "2. Project ID: odin-secure-comm-org" -ForegroundColor White
Write-Host "3. Link to billing account" -ForegroundColor White
Write-Host "4. Enable required APIs" -ForegroundColor White
Write-Host ""

Write-Host "⚠️  CURRENT SITUATION ASSESSMENT:" -ForegroundColor Red
Write-Host ""
# Check current user
$currentUser = gcloud auth list --filter=status:ACTIVE --format="value(account)"
Write-Host "Current User: $currentUser" -ForegroundColor White

if ($currentUser -like "*odinprotocol.dev") {
    Write-Host "✅ You're using odinprotocol.dev email" -ForegroundColor Green
    
    # Check for organization
    try {
        $hasOrg = gcloud organizations list --format="value(name)" 2>$null
        if ($hasOrg) {
            Write-Host "✅ You have access to organizations" -ForegroundColor Green
            gcloud organizations list --format="table(displayName,name,domain)"
        } else {
            Write-Host "❌ No organization access - Google Workspace setup likely needed" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Cannot access organizations - Google Workspace setup required" -ForegroundColor Red
    }
} else {
    Write-Host "❌ You're not using odinprotocol.dev email" -ForegroundColor Red
    Write-Host "   Switch to admin odinprotocol.dev or similar" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎯 RECOMMENDED NEXT ACTIONS:" -ForegroundColor Cyan
Write-Host ""

if ($currentUser -like "*odinprotocol.dev") {
    Write-Host "Since you're using odinprotocol.dev:" -ForegroundColor Green
    Write-Host "1. Verify Google Workspace is set up for odinprotocol.dev domain" -ForegroundColor White
    Write-Host "2. Ensure you have Super Admin role in Workspace" -ForegroundColor White
    Write-Host "3. Access Cloud Console to trigger organization creation" -ForegroundColor White
    Write-Host "4. Then run this script again to verify" -ForegroundColor White
} else {
    Write-Host "1. Set up Google Workspace for odinprotocol.dev domain" -ForegroundColor White
    Write-Host "2. Create admin odinprotocol.dev account" -ForegroundColor White  
    Write-Host "3. Authenticate with: gcloud auth login admin odinprotocol.dev" -ForegroundColor White
    Write-Host "4. Access Cloud Console to create organization" -ForegroundColor White
}

Write-Host ""
Write-Host "🔗 HELPFUL LINKS:" -ForegroundColor Cyan
Write-Host "• Google Workspace Setup: https://workspace.google.com" -ForegroundColor Blue
Write-Host "• Domain Verification: https://admin.google.com" -ForegroundColor Blue
Write-Host "• Cloud Console: https://console.cloud.google.com" -ForegroundColor Blue
Write-Host "• Organization Setup: https://cloud.google.com/resource-manager/docs/creating-managing-organization" -ForegroundColor Blue
Write-Host ""

Write-Host "AFTER ORGANIZATION IS CREATED:" -ForegroundColor Yellow
Write-Host "Run: .\scripts\setup_org_vpc.ps1 to configure VPC under organization" -ForegroundColor White
