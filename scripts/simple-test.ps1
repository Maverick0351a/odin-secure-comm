# Simple ODIN Endpoint Test
param(
    [string]$BaseUrl = "https://odin-gateway-583712448463.us-central1.run.app"
)

Write-Host "Testing ODIN Endpoints" -ForegroundColor Green
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan

try {
    # Get identity token
    Write-Host "Getting identity token..." -ForegroundColor Yellow
    $token = gcloud auth print-identity-token 2>$null
    
    if (-not $token) {
        Write-Host "Failed to get identity token" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Token obtained" -ForegroundColor Green
    
    # Test health endpoint
    Write-Host "Testing health endpoint..." -ForegroundColor Yellow
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    $healthResponse = Invoke-RestMethod -Uri "$BaseUrl/health" -Headers $headers -Method GET
    Write-Host "Health check passed" -ForegroundColor Green
    Write-Host "Response: $($healthResponse | ConvertTo-Json)" -ForegroundColor Cyan
    
    # Test discovery endpoint
    Write-Host "Testing discovery endpoint..." -ForegroundColor Yellow
    $discoveryResponse = Invoke-RestMethod -Uri "$BaseUrl/.well-known/odin/discovery.json" -Headers $headers -Method GET
    Write-Host "Discovery check passed" -ForegroundColor Green
    Write-Host "Response: $($discoveryResponse | ConvertTo-Json -Depth 3)" -ForegroundColor Cyan
    
    # Test JWKS endpoint
    Write-Host "Testing JWKS endpoint..." -ForegroundColor Yellow
    $jwksResponse = Invoke-RestMethod -Uri "$BaseUrl/.well-known/jwks.json" -Headers $headers -Method GET
    Write-Host "JWKS check passed" -ForegroundColor Green
    Write-Host "Keys found: $($jwksResponse.keys.Count)" -ForegroundColor Cyan
    
    Write-Host "All endpoint tests passed!" -ForegroundColor Green
    
} catch {
    Write-Host "Test failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
    exit 1
}
