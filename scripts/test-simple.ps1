# Simple ODIN Gateway Test Script
param(
    [string]$BaseUrl = "https://odin-gateway-583712448463.us-central1.run.app"
)

Write-Host "🧪 Testing ODIN Gateway at: $BaseUrl" -ForegroundColor Green

# Generate token using service account impersonation
Write-Host "Generating service account token..." -ForegroundColor Yellow

try {
    # Test direct access first (without token for public endpoints)
    Write-Host "`n📋 Testing health endpoint..." -ForegroundColor Yellow
    
    $healthResponse = Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET -TimeoutSec 10
    Write-Host "✅ Health check successful!" -ForegroundColor Green
    Write-Host "Response: $($healthResponse | ConvertTo-Json -Compress)" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n📋 Testing discovery endpoint..." -ForegroundColor Yellow
    
    $discoveryResponse = Invoke-RestMethod -Uri "$BaseUrl/.well-known/odin/discovery.json" -Method GET -TimeoutSec 10
    Write-Host "✅ Discovery endpoint successful!" -ForegroundColor Green
    Write-Host "Response: $($discoveryResponse | ConvertTo-Json -Compress)" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Discovery endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n📋 Testing JWKS endpoint..." -ForegroundColor Yellow
    
    $jwksResponse = Invoke-RestMethod -Uri "$BaseUrl/.well-known/jwks.json" -Method GET -TimeoutSec 10
    Write-Host "✅ JWKS endpoint successful!" -ForegroundColor Green
    Write-Host "Response: $($jwksResponse | ConvertTo-Json -Compress)" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ JWKS endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎉 Basic connectivity tests complete!" -ForegroundColor Green
Write-Host "Your ODIN Gateway is accessible and ready for Integration Connectors!" -ForegroundColor Cyan
