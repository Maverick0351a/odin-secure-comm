#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Get ID token and test ODIN Protocol endpoints
.DESCRIPTION
    Retrieves a Google Cloud ID token and performs smoke tests on ODIN Protocol endpoints
.PARAMETER BaseUrl
    Base URL of the ODIN Gateway service (e.g., https://odin-gateway-xyz.run.app)
.EXAMPLE
    .\scripts\identity-token.ps1 -BaseUrl "https://odin-gateway-xyz.run.app"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BaseUrl
)

Write-Host "=== ODIN Protocol Endpoint Testing ===" -ForegroundColor Green
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan
Write-Host ""

# Get ID token
Write-Host "Getting ID token..." -ForegroundColor Yellow
try {
    $idToken = gcloud auth print-identity-token 2>$null
    if (-not $idToken -or $LASTEXITCODE -ne 0) {
        throw "Failed to get ID token"
    }
    Write-Host "✅ ID token obtained" -ForegroundColor Green
    Write-Host "Token: $($idToken.Substring(0, 50))..." -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to get ID token: $_" -ForegroundColor Red
    Write-Host "Run: gcloud auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "TOKEN=$idToken"
Write-Host ""

# Common headers
$headers = @{
    "Authorization" = "Bearer $idToken"
    "Content-Type" = "application/json"
}

# Test 1: Health check
Write-Host "🩺 Testing health endpoint..." -ForegroundColor Cyan
try {
    $healthUrl = "$BaseUrl/health"
    $response = Invoke-RestMethod -Uri $healthUrl -Method Get -Headers $headers -TimeoutSec 10
    if ($response.ok -eq $true) {
        Write-Host "✅ Health check passed" -ForegroundColor Green
        Write-Host "   Status: $($response.status)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Health check returned: $($response | ConvertTo-Json -Compress)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Discovery endpoint
Write-Host ""
Write-Host "🔍 Testing discovery endpoint..." -ForegroundColor Cyan
try {
    $discoveryUrl = "$BaseUrl/.well-known/odin/discovery.json"
    $response = Invoke-RestMethod -Uri $discoveryUrl -Method Get -Headers $headers -TimeoutSec 10
    if ($response.protocol -eq "ODIN") {
        Write-Host "✅ Discovery endpoint working" -ForegroundColor Green
        Write-Host "   Protocol: $($response.protocol) v$($response.version)" -ForegroundColor Gray
        Write-Host "   Issuer: $($response.issuer)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Discovery returned: $($response | ConvertTo-Json -Compress)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Discovery failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: JWKS endpoint
Write-Host ""
Write-Host "🔑 Testing JWKS endpoint..." -ForegroundColor Cyan
try {
    $jwksUrl = "$BaseUrl/.well-known/jwks.json"
    $response = Invoke-RestMethod -Uri $jwksUrl -Method Get -Headers $headers -TimeoutSec 10
    if ($response.keys -and $response.keys.Count -gt 0) {
        Write-Host "✅ JWKS endpoint working" -ForegroundColor Green
        Write-Host "   Keys found: $($response.keys.Count)" -ForegroundColor Gray
        $response.keys | ForEach-Object {
            Write-Host "   - Kid: $($_.kid), Alg: $($_.alg)" -ForegroundColor Gray
        }
    } else {
        Write-Host "⚠️  JWKS returned no keys: $($response | ConvertTo-Json -Compress)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ JWKS failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Envelope endpoint (POST)
Write-Host ""
Write-Host "📧 Testing envelope endpoint..." -ForegroundColor Cyan

# Generate test trace ID and CID
$traceId = [System.Guid]::NewGuid().ToString()
$payloadCid = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"

$envelopeHeaders = $headers.Clone()
$envelopeHeaders["X-ODIN-Trace-Id"] = $traceId
$envelopeHeaders["X-ODIN-Payload-CID"] = $payloadCid

$testEnvelope = @{
    recipient = "test-ai-agent"
    message = "Test message from ODIN connector validation"
    signature = "MEUCIQDKj9kExample"  # Example signature
    public_key = "MCowBQYDK2VwAyEAExample"  # Example public key
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
} | ConvertTo-Json

try {
    $envelopeUrl = "$BaseUrl/v1/envelope"
    Write-Host "   Trace ID: $traceId" -ForegroundColor Gray
    Write-Host "   Payload CID: $payloadCid" -ForegroundColor Gray
    
    $response = Invoke-RestMethod -Uri $envelopeUrl -Method Post -Headers $envelopeHeaders -Body $testEnvelope -TimeoutSec 10
    if ($response.ok -eq $true) {
        Write-Host "✅ Envelope endpoint working" -ForegroundColor Green
        Write-Host "   Receipt ID: $($response.receipt.receipt_id)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Envelope returned: $($response | ConvertTo-Json -Compress)" -ForegroundColor Yellow
    }
} catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*400*" -or $errorMessage -like "*signature*") {
        Write-Host "✅ Envelope endpoint accessible (signature validation working)" -ForegroundColor Green
        Write-Host "   Expected 400 due to test signature" -ForegroundColor Gray
    } else {
        Write-Host "❌ Envelope failed: $errorMessage" -ForegroundColor Red
    }
}

# Test 5: Receipt hops endpoint
Write-Host ""
Write-Host "📋 Testing receipt hops endpoint..." -ForegroundColor Cyan
try {
    $hopsUrl = "$BaseUrl/v1/receipts/hops?trace_id=$traceId"
    $response = Invoke-RestMethod -Uri $hopsUrl -Method Get -Headers $headers -TimeoutSec 10
    if ($response.hops) {
        Write-Host "✅ Receipt hops endpoint working" -ForegroundColor Green
        Write-Host "   Hops found: $($response.hops.Count)" -ForegroundColor Gray
    } else {
        Write-Host "✅ Receipt hops endpoint accessible (no hops for test trace)" -ForegroundColor Green
    }
} catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*404*") {
        Write-Host "✅ Receipt hops endpoint accessible (404 expected for test trace)" -ForegroundColor Green
    } else {
        Write-Host "❌ Receipt hops failed: $errorMessage" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Green
Write-Host "Tested endpoints against: $BaseUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Import openapi/odin-connector.yaml into Integration Connectors" -ForegroundColor White
Write-Host "2. Create a Connection with base URL: $BaseUrl" -ForegroundColor White
Write-Host "3. Use the token above for testing in the connector UI" -ForegroundColor White
Write-Host ""
Write-Host "Token for copy/paste:" -ForegroundColor Yellow
Write-Host "$idToken" -ForegroundColor White
