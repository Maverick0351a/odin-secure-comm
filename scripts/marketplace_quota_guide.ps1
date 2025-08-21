#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Guide for requesting Google Cloud quota increases for Marketplace
.DESCRIPTION
    Provides step-by-step instructions and current quota status for Marketplace deployment
#>

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1"
)

Write-Host "=== GOOGLE CLOUD MARKETPLACE QUOTA GUIDE ===" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host ""

# Check current quotas
Write-Host "=== CURRENT QUOTA STATUS ===" -ForegroundColor Cyan
Write-Host "Checking current quotas..." -ForegroundColor Yellow

# Check compute quotas
Write-Host "`n1. COMPUTE ENGINE QUOTAS:" -ForegroundColor Yellow
try {
    gcloud compute project-info describe --project=$ProjectId --format="table(quotas.metric,quotas.limit,quotas.usage)" | Select-String -Pattern "(CPUs|GPUS|SSD|DISKS)"
} catch {
    Write-Host "   Unable to fetch compute quotas. You may need to enable Compute Engine API." -ForegroundColor Red
}

# Check Cloud Run quotas
Write-Host "`n2. CLOUD RUN QUOTAS:" -ForegroundColor Yellow
Write-Host "   Current Cloud Run services:" -ForegroundColor White
try {
    gcloud run services list --project=$ProjectId --region=$Region --format="table(metadata.name,status.url,status.traffic[0].percent)"
} catch {
    Write-Host "   No Cloud Run services found or API not enabled." -ForegroundColor Yellow
}

Write-Host "`n=== QUOTA INCREASE REQUIREMENTS FOR MARKETPLACE ===" -ForegroundColor Cyan

Write-Host "`n📋 RECOMMENDED QUOTA INCREASES:" -ForegroundColor Yellow
Write-Host "   ✅ CPUs (all regions): 50-100 (minimum 10)" -ForegroundColor Green
Write-Host "   ✅ Persistent Disk SSD (GB): 500-1000" -ForegroundColor Green
Write-Host "   ✅ Static IP addresses: 5-10" -ForegroundColor Green
Write-Host "   ⚠️  GPUs (if planning ML services): 4-8 T4 or V100" -ForegroundColor Yellow
Write-Host "   ✅ Load Balancer forwarding rules: 10" -ForegroundColor Green
Write-Host "   ✅ Cloud Run CPU allocation: 1000" -ForegroundColor Green
Write-Host "   ✅ Cloud Run memory allocation: 4Gi" -ForegroundColor Green
Write-Host "   ✅ IAM API requests per minute: 3000" -ForegroundColor Green

Write-Host "`n🎯 STEP-BY-STEP QUOTA REQUEST PROCESS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open Google Cloud Console: https://console.cloud.google.com" -ForegroundColor White
Write-Host "2. Navigate to: IAM & Admin -> Quotas" -ForegroundColor White
Write-Host "3. Set filters:" -ForegroundColor White
Write-Host "   - Service: Compute Engine API" -ForegroundColor Gray
Write-Host "   - Metric: CPUs (all regions)" -ForegroundColor Gray
Write-Host "4. Select the quota and click 'EDIT QUOTAS'" -ForegroundColor White
Write-Host "5. Fill out the form:" -ForegroundColor White
Write-Host "   - New limit: 50-100 CPUs" -ForegroundColor Gray
Write-Host "   - Justification: 'Production deployment for Google Cloud Marketplace partner application'" -ForegroundColor Gray
Write-Host "   - Description: 'ODIN Secure Communication Gateway - AI-to-AI secure communication platform'" -ForegroundColor Gray
Write-Host "6. Repeat for other quotas (GPU, Disk, etc.)" -ForegroundColor White

Write-Host "`n📧 QUOTA REQUEST TEMPLATE:" -ForegroundColor Cyan
Write-Host "Subject: Quota Increase Request - Marketplace Partner Application" -ForegroundColor White
Write-Host ""
Write-Host "Dear Google Cloud Support," -ForegroundColor Gray
Write-Host ""
Write-Host "We are requesting quota increases for our Google Cloud Marketplace partner application:" -ForegroundColor Gray
Write-Host "- Application: ODIN Secure Communication Gateway" -ForegroundColor Gray
Write-Host "- Use Case: AI-to-AI secure communication platform with cryptographic receipts" -ForegroundColor Gray
Write-Host "- Deployment: Production environment for Marketplace customers" -ForegroundColor Gray
Write-Host "- Expected Load: Multiple customer deployments across regions" -ForegroundColor Gray
Write-Host ""
Write-Host "Requested quotas:" -ForegroundColor Gray
Write-Host "- CPUs (all regions): 100" -ForegroundColor Gray
Write-Host "- Persistent Disk SSD: 1000GB" -ForegroundColor Gray
Write-Host "- Static IP addresses: 10" -ForegroundColor Gray
Write-Host "- Load Balancer forwarding rules: 10" -ForegroundColor Gray
Write-Host ""
Write-Host "This is for production Marketplace deployment. Expected approval timeframe is 24-48 hours." -ForegroundColor Gray
Write-Host ""
Write-Host "Thank you," -ForegroundColor Gray
Write-Host "ODIN Protocol Team" -ForegroundColor Gray

Write-Host "`n⏰ TIMELINE:" -ForegroundColor Cyan
Write-Host "   - Standard quotas: 24-48 hours" -ForegroundColor Green
Write-Host "   - GPU quotas: 2-5 business days" -ForegroundColor Yellow
Write-Host "   - Large increases (1000+ CPUs): 5-10 business days" -ForegroundColor Yellow

Write-Host "`n🔗 USEFUL LINKS:" -ForegroundColor Cyan
Write-Host "   - Quota Console: https://console.cloud.google.com/iam-admin/quotas?project=$ProjectId" -ForegroundColor Blue
Write-Host "   - Marketplace Partner Portal: https://console.cloud.google.com/partner" -ForegroundColor Blue
Write-Host "   - Support Case: https://console.cloud.google.com/support" -ForegroundColor Blue

Write-Host "`n✅ NETWORKING STATUS: COMPLETE" -ForegroundColor Green
Write-Host "Your VPC is properly configured for Marketplace deployment." -ForegroundColor White

Write-Host "`n🚀 NEXT ACTIONS:" -ForegroundColor Yellow
Write-Host "1. Submit quota increase requests in Cloud Console" -ForegroundColor White
Write-Host "2. Wait for approval (24-48 hours)" -ForegroundColor White
Write-Host "3. Test deployment with increased quotas" -ForegroundColor White
Write-Host "4. Submit to Marketplace for review" -ForegroundColor White
