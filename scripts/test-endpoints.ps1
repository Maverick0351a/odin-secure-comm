# ODIN Protocol Endpoint Testing Script
# Tests all ODIN Gateway endpoints with proper authentication

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,
    
    [string]$Region = "us-central1",
    [string]$ServiceName = "odin-gateway",
    [string]$BaseUrl = "",
    [switch]$Verbose
)

# Set up error handling
$ErrorActionPreference = "Stop"

Write-Host "🧪 ODIN Protocol Endpoint Testing" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Service: $ServiceName" -ForegroundColor Cyan

# Function to make authenticated HTTP requests
function Invoke-OdinRequest {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = $null,
        [string]$Description
    )
    
    try {
        Write-Host "`n🔍 Testing: $Description" -ForegroundColor Yellow
        Write-Host "URL: $Url" -ForegroundColor Gray
        Write-Host "Method: $Method" -ForegroundColor Gray
        
        # Get identity token
        $token = gcloud auth print-identity-token --audiences=$script:BaseUrl 2>$null
        if (-not $token) {
            throw "Failed to get identity token"
        }
        
        # Prepare headers
        $requestHeaders = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
            "User-Agent" = "ODIN-Test-Script/1.0"
        }
        
        # Add custom headers
        foreach ($key in $Headers.Keys) {
            $requestHeaders[$key] = $Headers[$key]
        }
        
        if ($Verbose) {
            Write-Host "Headers:" -ForegroundColor Gray
            foreach ($key in $requestHeaders.Keys) {
                if ($key -eq "Authorization") {
                    Write-Host "  $key: Bearer <token>" -ForegroundColor Gray
                } else {
                    Write-Host "  $key: $($requestHeaders[$key])" -ForegroundColor Gray
                }
            }
        }
        
        # Make request
        $response = if ($Body) {
            Invoke-RestMethod -Uri $Url -Method $Method -Headers $requestHeaders -Body $Body -TimeoutSec 30
        } else {
            Invoke-RestMethod -Uri $Url -Method $Method -Headers $requestHeaders -TimeoutSec 30
        }
        
        Write-Host "✅ SUCCESS: $Description" -ForegroundColor Green
        
        if ($Verbose) {
            Write-Host "Response:" -ForegroundColor Gray
            $response | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Cyan
        }
        
        return @{ Success = $true; Response = $response; Error = $null }
        
    } catch {
        Write-Host "❌ FAILED: $Description" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            Write-Host "Status Code: $statusCode" -ForegroundColor Red
        }
        
        return @{ Success = $false; Response = $null; Error = $_.Exception.Message }
    }
}

# Get the base URL
if (-not $BaseUrl) {
    Write-Host "`n🔍 Discovering service URL..." -ForegroundColor Yellow
    
    try {
        $serviceInfo = gcloud run services describe $ServiceName --region=$Region --project=$ProjectId --format="value(status.url)" 2>$null
        if ($serviceInfo) {
            $script:BaseUrl = $serviceInfo.Trim()
            Write-Host "✅ Service URL: $script:BaseUrl" -ForegroundColor Green
        } else {
            throw "Service not found or not accessible"
        }
    } catch {
        Write-Host "❌ Failed to get service URL. Is the service deployed?" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    $script:BaseUrl = $BaseUrl
}

# Initialize test results
$testResults = @()

Write-Host "`n🚀 Starting endpoint tests..." -ForegroundColor Green

# Test 1: Health Check
$result = Invoke-OdinRequest -Url "$script:BaseUrl/health" -Method "GET" -Description "Health Check"
$testResults += @{ Name = "Health Check"; Result = $result }

# Test 2: Discovery Configuration
$result = Invoke-OdinRequest -Url "$script:BaseUrl/.well-known/odin/discovery.json" -Method "GET" -Description "ODIN Discovery"
$testResults += @{ Name = "ODIN Discovery"; Result = $result }

# Test 3: JWKS Public Keys
$result = Invoke-OdinRequest -Url "$script:BaseUrl/.well-known/jwks.json" -Method "GET" -Description "JWKS Public Keys"
$testResults += @{ Name = "JWKS Public Keys"; Result = $result }

# Test 4: Send Message Envelope
$traceId = [System.Guid]::NewGuid().ToString()
$timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$envelopeBody = @{
    recipient = "test-ai-agent"
    message = "Hello from PowerShell test script"
    signature = "MEUCIQDKj9kExampleSignatureBase64Encoded123456789"
    public_key = "MCowBQYDK2VwAyEAExamplePublicKeyBase64Encoded123"
    timestamp = $timestamp
} | ConvertTo-Json -Depth 10

$headers = @{
    "X-ODIN-Trace-Id" = $traceId
    "X-ODIN-Payload-CID" = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
}

$result = Invoke-OdinRequest -Url "$script:BaseUrl/v1/envelope" -Method "POST" -Headers $headers -Body $envelopeBody -Description "Send Message Envelope"
$testResults += @{ Name = "Send Message Envelope"; Result = $result }

# Test 5: Get Receipt Hops (using the trace ID from envelope test)
$result = Invoke-OdinRequest -Url "$script:BaseUrl/v1/receipts/hops?trace_id=$traceId" -Method "GET" -Description "Get Receipt Hops"
$testResults += @{ Name = "Get Receipt Hops"; Result = $result }

# Test 6: Get Receipt Chain (using the trace ID from envelope test)
$result = Invoke-OdinRequest -Url "$script:BaseUrl/v1/receipts/hops/chain/$traceId" -Method "GET" -Description "Get Receipt Chain"
$testResults += @{ Name = "Get Receipt Chain"; Result = $result }

# Test 7: Error Handling - Invalid endpoint
$result = Invoke-OdinRequest -Url "$script:BaseUrl/v1/invalid-endpoint" -Method "GET" -Description "Error Handling Test"
$testResults += @{ Name = "Error Handling"; Result = $result }

# Generate test report
Write-Host "`n" + "="*60 -ForegroundColor Blue
Write-Host "📋 TEST RESULTS SUMMARY" -ForegroundColor Blue
Write-Host "="*60 -ForegroundColor Blue

$passed = 0
$failed = 0

foreach ($test in $testResults) {
    $status = if ($test.Result.Success) { 
        $passed++
        "✅ PASS" 
    } else { 
        $failed++
        "❌ FAIL" 
    }
    
    Write-Host "$status $($test.Name)" -ForegroundColor $(if ($test.Result.Success) { "Green" } else { "Red" })
    
    if (-not $test.Result.Success -and $test.Result.Error) {
        Write-Host "  Error: $($test.Result.Error)" -ForegroundColor Red
    }
}

Write-Host "`n" + "="*60 -ForegroundColor Blue
Write-Host "📊 SUMMARY: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })

# Additional information
Write-Host "`n📋 Test Configuration:" -ForegroundColor Cyan
Write-Host "Project ID: $ProjectId" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "Service: $ServiceName" -ForegroundColor White
Write-Host "Base URL: $script:BaseUrl" -ForegroundColor White
Write-Host "Trace ID: $traceId" -ForegroundColor White

# curl equivalents for manual testing
Write-Host "`n🔧 Manual Testing Commands:" -ForegroundColor Yellow
Write-Host "# Get ID token:" -ForegroundColor Gray
Write-Host "gcloud auth print-identity-token --audiences=$script:BaseUrl" -ForegroundColor Cyan

Write-Host "`n# Test health endpoint:" -ForegroundColor Gray
Write-Host "curl -H `"Authorization: Bearer `$(gcloud auth print-identity-token --audiences=$script:BaseUrl)`" \\" -ForegroundColor Cyan
Write-Host "     `"$script:BaseUrl/health`"" -ForegroundColor Cyan

Write-Host "`n# Test envelope endpoint:" -ForegroundColor Gray
Write-Host "curl -X POST \\" -ForegroundColor Cyan
Write-Host "     -H `"Authorization: Bearer `$(gcloud auth print-identity-token --audiences=$script:BaseUrl)`" \\" -ForegroundColor Cyan
Write-Host "     -H `"Content-Type: application/json`" \\" -ForegroundColor Cyan
Write-Host "     -H `"X-ODIN-Trace-Id: $traceId`" \\" -ForegroundColor Cyan
Write-Host "     -d '{`"recipient`":`"test-agent`",`"message`":`"test`"}' \\" -ForegroundColor Cyan
Write-Host "     `"$script:BaseUrl/v1/envelope`"" -ForegroundColor Cyan

if ($failed -eq 0) {
    Write-Host "`n🎉 All tests passed! ODIN Gateway is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️ Some tests failed. Check the errors above and verify your deployment." -ForegroundColor Yellow
    exit 1
}
