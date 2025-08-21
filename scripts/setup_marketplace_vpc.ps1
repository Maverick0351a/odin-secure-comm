#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure VPC for Google Cloud Marketplace
.DESCRIPTION
    Sets up networking requirements for Marketplace partner deployment
#>

param(
    [string]$ProjectId = "odin-ai-to",
    [string[]]$Regions = @("us-central1", "us-east1", "europe-west1")
)

Write-Host "=== CONFIGURING VPC FOR MARKETPLACE ===" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor White
Write-Host "Regions: $($Regions -join ', ')" -ForegroundColor White
Write-Host ""

# Set project
gcloud config set project $ProjectId

# Enable required APIs
Write-Host "Enabling required APIs..." -ForegroundColor Yellow
$apis = @(
    "compute.googleapis.com",
    "container.googleapis.com", 
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "  Enabling $api..." -ForegroundColor White
    gcloud services enable $api --project=$ProjectId
}

# Create default VPC if it doesn't exist
Write-Host "`nConfiguring default VPC network..." -ForegroundColor Yellow
$networkExists = gcloud compute networks list --project=$ProjectId --format="value(name)" | Select-String -Pattern "^default$"

if (-not $networkExists) {
    Write-Host "  Creating default VPC network..." -ForegroundColor White
    gcloud compute networks create default `
        --project=$ProjectId `
        --subnet-mode=auto `
        --bgp-routing-mode=global
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Default VPC created" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to create VPC" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✅ Default VPC already exists" -ForegroundColor Green
}

# Create essential firewall rules for Marketplace
Write-Host "`nConfiguring firewall rules for Marketplace..." -ForegroundColor Yellow

$firewallRules = @(
    @{
        name = "default-allow-icmp"
        allow = "icmp"
        sources = @()
        description = "Allow ICMP from anywhere"
    },
    @{
        name = "default-allow-internal"
        allow = "tcp,udp,icmp"
        sources = @("10.128.0.0/9")
        description = "Allow internal communication"
    },
    @{
        name = "default-allow-ssh"
        allow = "tcp:22"
        sources = @("0.0.0.0/0")
        description = "Allow SSH from anywhere"
    },
    @{
        name = "allow-https-lb"
        allow = "tcp:443"
        sources = @("130.211.0.0/22", "35.191.0.0/16")
        description = "Allow HTTPS from Google Load Balancer"
    },
    @{
        name = "allow-health-check"
        allow = "tcp:8080"
        sources = @("130.211.0.0/22", "35.191.0.0/16")
        description = "Allow health checks to application port"
    }
)

foreach ($rule in $firewallRules) {
    Write-Host "  Creating firewall rule: $($rule.name)..." -ForegroundColor White
    
    $cmd = "gcloud compute firewall-rules create $($rule.name) --project=$ProjectId --network=default --allow=$($rule.allow)"
    if ($rule.sources.Count -gt 0) {
        $cmd += " --source-ranges=$($rule.sources -join ',')"
    }
    $cmd += " --description=`"$($rule.description)`""
    
    try {
        Invoke-Expression $cmd
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✅ $($rule.name) created" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "    ⚠️ $($rule.name) may already exist" -ForegroundColor Yellow
    }
}

# Verify subnets exist in required regions
Write-Host "`nVerifying regional subnets..." -ForegroundColor Yellow
foreach ($region in $Regions) {
    $subnet = gcloud compute networks subnets list --project=$ProjectId --regions=$region --filter="network:default" --format="value(name)"
    if ($subnet) {
        Write-Host "  ✅ Subnet exists in $region" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ No subnet found in $region (auto-mode should create on-demand)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== VPC CONFIGURATION SUMMARY ===" -ForegroundColor Cyan
gcloud compute networks list --project=$ProjectId --format="table(name,mode,bgpRoutingMode)"
Write-Host ""
gcloud compute firewall-rules list --project=$ProjectId --filter="network:default" --format="table(name,allowed,sourceRanges)"

Write-Host "`n✅ VPC configuration complete for Marketplace deployment!" -ForegroundColor Green
Write-Host "`nNext step: Request quota increases in Google Cloud Console" -ForegroundColor Yellow
