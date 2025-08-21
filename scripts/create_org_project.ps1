#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create ODIN Secure Communication project under odinprotocol.dev organization
.DESCRIPTION
    Sets up a new GCP project under the ODIN Protocol organization with proper naming and configuration
#>

param(
    [string]$OrganizationId = "",
    [string]$NewProjectId = "odin-secure-comm-prod",
    [string]$BillingAccountId = ""
)

Write-Host "=== CREATING ORGANIZATION PROJECT ===" -ForegroundColor Green
Write-Host "Target Organization: odinprotocol.dev" -ForegroundColor White
Write-Host "New Project ID: $NewProjectId" -ForegroundColor White
Write-Host ""

# Step 1: Find the organization
Write-Host "Step 1: Finding odinprotocol.dev organization..." -ForegroundColor Yellow
try {
    $orgs = gcloud organizations list --format="csv(name,displayName,domain)" --quiet
    Write-Host "Available organizations:" -ForegroundColor White
    foreach ($org in $orgs) {
        if ($org -ne "name,displayName,domain") {
            Write-Host "  $org" -ForegroundColor Gray
        }
    }
    
    # Try to find ODIN organization
    $odinOrg = gcloud organizations list --filter="domain:odinprotocol.dev" --format="value(name)" --quiet
    if (-not $odinOrg) {
        $odinOrg = gcloud organizations list --filter="displayName:*odin*" --format="value(name)" --quiet
    }
    
    if ($odinOrg) {
        Write-Host "✅ Found organization: $odinOrg" -ForegroundColor Green
        $OrganizationId = $odinOrg
    } else {
        Write-Host "❌ Could not find odinprotocol.dev organization" -ForegroundColor Red
        Write-Host "You may need to:" -ForegroundColor Yellow
        Write-Host "  1. Set up Google Workspace for odinprotocol.dev domain" -ForegroundColor White
        Write-Host "  2. Create a Google Cloud Organization" -ForegroundColor White
        Write-Host "  3. Get organization admin permissions" -ForegroundColor White
        exit 1
    }
} catch {
    Write-Host "❌ Failed to access organizations. Check permissions." -ForegroundColor Red
    exit 1
}

# Step 2: Check billing accounts
Write-Host "`nStep 2: Finding billing account..." -ForegroundColor Yellow
try {
    $billingAccounts = gcloud billing accounts list --format="table(name,displayName,open)" --quiet
    Write-Host "Available billing accounts:" -ForegroundColor White
    gcloud billing accounts list --format="table(displayName,name,open)" --quiet
    
    if (-not $BillingAccountId) {
        $openAccounts = gcloud billing accounts list --filter="open:true" --format="value(name)" --quiet
        if ($openAccounts) {
            $BillingAccountId = $openAccounts[0]
            Write-Host "✅ Using billing account: $BillingAccountId" -ForegroundColor Green
        } else {
            Write-Host "❌ No open billing accounts found. Please set up billing first." -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "❌ Failed to access billing accounts" -ForegroundColor Red
    exit 1
}

# Step 3: Create the project
Write-Host "`nStep 3: Creating project under organization..." -ForegroundColor Yellow
try {
    gcloud projects create $NewProjectId `
        --organization=$OrganizationId `
        --name="ODIN Secure Communication" `
        --labels="environment=production,team=odin-protocol,purpose=marketplace"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Project created successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to create project. It may already exist." -ForegroundColor Red
        # Check if project exists
        $existingProject = gcloud projects describe $NewProjectId --format="value(projectId)" 2>$null
        if ($existingProject) {
            Write-Host "ℹ️  Project $NewProjectId already exists. Continuing..." -ForegroundColor Blue
        } else {
            exit 1
        }
    }
} catch {
    Write-Host "❌ Project creation failed" -ForegroundColor Red
    exit 1
}

# Step 4: Link billing
Write-Host "`nStep 4: Linking billing account..." -ForegroundColor Yellow
try {
    gcloud billing projects link $NewProjectId --billing-account=$BillingAccountId
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Billing linked successfully!" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Billing link may have failed - check manually" -ForegroundColor Yellow
}

# Step 5: Set as active project
Write-Host "`nStep 5: Setting as active project..." -ForegroundColor Yellow
gcloud config set project $NewProjectId
Write-Host "✅ Active project set to: $NewProjectId" -ForegroundColor Green

# Step 6: Enable required APIs
Write-Host "`nStep 6: Enabling required APIs..." -ForegroundColor Yellow
$apis = @(
    "compute.googleapis.com",
    "run.googleapis.com", 
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "  Enabling $api..." -ForegroundColor White
    gcloud services enable $api --project=$NewProjectId
}

Write-Host "`n=== ORGANIZATION PROJECT SETUP COMPLETE ===" -ForegroundColor Green
Write-Host "Organization Project: $NewProjectId" -ForegroundColor White
Write-Host "Organization: $OrganizationId" -ForegroundColor White
Write-Host "Billing: $BillingAccountId" -ForegroundColor White
Write-Host ""
Write-Host "🚀 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Run: .\scripts\setup_simple.ps1 to configure GCP resources" -ForegroundColor White
Write-Host "2. Run: .\scripts\deploy_clean.ps1 to deploy ODIN Gateway" -ForegroundColor White
Write-Host "3. Update GitHub repository secrets with new project ID" -ForegroundColor White
Write-Host ""
Write-Host "📝 GITHUB SECRETS TO UPDATE:" -ForegroundColor Cyan
Write-Host "  GCP_PROJECT_ID: $NewProjectId" -ForegroundColor Gray
