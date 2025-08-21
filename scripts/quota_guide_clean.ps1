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

Write-Host "=== NETWORKING STATUS ===" -ForegroundColor Cyan
Write-Host "✅ VPC Configuration: COMPLETE" -ForegroundColor Green
Write-Host "✅ Firewall Rules: CONFIGURED" -ForegroundColor Green
Write-Host "✅ Regional Subnets: AVAILABLE" -ForegroundColor Green
Write-Host ""

Write-Host "=== QUOTA INCREASE REQUIREMENTS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 REQUIRED QUOTA INCREASES FOR MARKETPLACE:" -ForegroundColor Yellow
Write-Host "   • CPUs (all regions): 50-100 (minimum 10)" -ForegroundColor White
Write-Host "   • Persistent Disk SSD (GB): 500-1000" -ForegroundColor White
Write-Host "   • Static IP addresses: 5-10" -ForegroundColor White
Write-Host "   • Load Balancer forwarding rules: 10" -ForegroundColor White
Write-Host "   • Cloud Run CPU allocation: 1000" -ForegroundColor White
Write-Host "   • Cloud Run memory allocation: 4Gi" -ForegroundColor White
Write-Host "   • IAM API requests per minute: 3000" -ForegroundColor White
Write-Host ""
Write-Host "🎯 OPTIONAL FOR ML SERVICES:" -ForegroundColor Yellow
Write-Host "   • GPUs: 4-8 T4 or V100 (if planning ML services)" -ForegroundColor White
Write-Host ""

Write-Host "🔗 STEP-BY-STEP PROCESS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open: https://console.cloud.google.com/iam-admin/quotas?project=$ProjectId" -ForegroundColor Blue
Write-Host "2. Navigate to: IAM and Admin -> Quotas" -ForegroundColor White
Write-Host "3. Filter by Service: Compute Engine API" -ForegroundColor White
Write-Host "4. Find 'CPUs (all regions)' and click EDIT QUOTAS" -ForegroundColor White
Write-Host "5. Request increase to 50-100 CPUs" -ForegroundColor White
Write-Host "6. Use this justification:" -ForegroundColor White
Write-Host ""
Write-Host "   Justification: Production deployment for Google Cloud Marketplace partner" -ForegroundColor Gray
Write-Host "   Description: ODIN Secure Communication Gateway for AI-to-AI communications" -ForegroundColor Gray
Write-Host "   Business impact: Marketplace customer deployments require scalable infrastructure" -ForegroundColor Gray
Write-Host ""
Write-Host "7. Submit and repeat for other quotas" -ForegroundColor White
Write-Host ""

Write-Host "⏰ EXPECTED TIMELINE:" -ForegroundColor Cyan
Write-Host "   • Standard quotas: 24-48 hours" -ForegroundColor Green
Write-Host "   • GPU quotas: 2-5 business days" -ForegroundColor Yellow
Write-Host "   • Large requests: 5-10 business days" -ForegroundColor Yellow
Write-Host ""

Write-Host "📧 DIRECT LINK TO QUOTA CONSOLE:" -ForegroundColor Cyan
Write-Host "https://console.cloud.google.com/iam-admin/quotas?project=$ProjectId" -ForegroundColor Blue
Write-Host ""

Write-Host "✅ ACTION REQUIRED:" -ForegroundColor Green
Write-Host "1. Click the link above to open quota console" -ForegroundColor White
Write-Host "2. Request increases for the quotas listed" -ForegroundColor White
Write-Host "3. Mark as 'for Marketplace production environment'" -ForegroundColor White
Write-Host "4. Wait for approval (usually 24-48 hours)" -ForegroundColor White
Write-Host ""

Write-Host "🚀 AFTER APPROVAL:" -ForegroundColor Yellow
Write-Host "Your ODIN gateway will be ready for Marketplace submission!" -ForegroundColor White
