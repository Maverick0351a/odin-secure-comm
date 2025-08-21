# ODIN Secure Communication - Authentication Test with Service Account Impersonation
# Tests all endpoints with properly minted ID token

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$ServiceAccount = "odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com",
    [string]$BaseUrl = "https://odin-gateway-583712448463.us-central1.run.app"
)

Write-Host "ODIN Authentication Test - Service Account Impersonation" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Service Account: $ServiceAccount" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan

# Mint ID token with proper impersonation and audience
Write-Host ""
Write-Host "Minting ID token with impersonation..." -ForegroundColor Yellow
try {
    $TOKEN = gcloud auth print-identity-token `
        --impersonate-service-account=$ServiceAccount `
        --audiences=$BaseUrl
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to mint ID token" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "ID token minted successfully" -ForegroundColor Green
    Write-Host "Token length: $($TOKEN.Length) characters" -ForegroundColor White
} catch {
    Write-Host "Error minting token: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test endpoints
$endpoints = @(
    @{ Method = "GET"; Path = "/health"; Description = "Health check" },
    @{ Method = "GET"; Path = "/.well-known/odin/discovery.json"; Description = "ODIN discovery" },
    @{ Method = "GET"; Path = "/.well-known/jwks.json"; Description = "JWKS endpoint" }
)

Write-Host ""
Write-Host "Testing endpoints..." -ForegroundColor Yellow

foreach ($endpoint in $endpoints) {
    $url = "$BaseUrl$($endpoint.Path)"
    Write-Host ""
    Write-Host "Testing: $($endpoint.Description)" -ForegroundColor Cyan
    Write-Host "URL: $url" -ForegroundColor White
    
    try {
        $headers = @{
            "Authorization" = "Bearer $TOKEN"
            "User-Agent" = "ODIN-Test-Client/1.0"
        }
        
        $response = Invoke-RestMethod -Uri $url -Method $endpoint.Method -Headers $headers
        Write-Host "Success" -ForegroundColor Green
        
        # Show response for discovery and JWKS
        if ($endpoint.Path -like "*discovery*" -or $endpoint.Path -like "*jwks*") {
            Write-Host "Response:" -ForegroundColor White
            $response | ConvertTo-Json -Depth 3
        } elseif ($endpoint.Path -like "*health*") {
            Write-Host "Status: $($response.status)" -ForegroundColor White
        }
    } catch {
        Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        }
    }
}

# Test envelope endpoint
Write-Host ""
Write-Host "Testing envelope endpoint (POST)..." -ForegroundColor Yellow
$envelopeUrl = "$BaseUrl/v1/envelope"
$testPayload = @{
    data = "test message"
    timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
} | ConvertTo-Json

try {
    $headers = @{
        "Authorization" = "Bearer $TOKEN"
        "Content-Type" = "application/json"
        "X-ODIN-Trace-Id" = "test-trace-$(Get-Random)"
        "X-ODIN-Payload-CID" = "test-cid-$(Get-Random)"
        "User-Agent" = "ODIN-Test-Client/1.0"
    }
    
    Write-Host "URL: $envelopeUrl" -ForegroundColor White
    Write-Host "Headers:" -ForegroundColor White
    foreach ($key in $headers.Keys) {
        if ($key -eq "Authorization") {
            Write-Host "  ${key}: Bearer [REDACTED]" -ForegroundColor Gray
        } else {
            Write-Host "  ${key}: $($headers[$key])" -ForegroundColor Gray
        }
    }
    
    $response = Invoke-RestMethod -Uri $envelopeUrl -Method POST -Headers $headers -Body $testPayload
    Write-Host "Envelope endpoint success" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor White
    $response | ConvertTo-Json -Depth 3
} catch {
    Write-Host "Envelope endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "All tests completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Open Google Cloud Console -> Application Integration -> Custom Connectors" -ForegroundColor White
Write-Host "2. Create custom connector using openapi/odin-openapi.yaml" -ForegroundColor White
Write-Host "3. Set authentication to Google ID Token with:" -ForegroundColor White
Write-Host "   - Service Account: $ServiceAccount" -ForegroundColor White
Write-Host "   - Audience: $BaseUrl" -ForegroundColor White
Write-Host "4. Create connection and test!" -ForegroundColor White
