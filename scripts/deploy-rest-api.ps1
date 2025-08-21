# ODIN Integration Connector - REST API Deployment
# Alternative deployment using Google Cloud REST APIs directly

param(
    [string]$ProjectId = "odin-ai-to",
    [string]$Region = "us-central1",
    [string]$ConnectorName = "odin-secure-comm",
    [string]$ServiceAccount = "odin-connector-invoker@odin-ai-to.iam.gserviceaccount.com",
    [string]$BaseUrl = "https://odin-gateway-583712448463.us-central1.run.app"
)

Write-Host "ODIN Integration Connector - REST API Deployment" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan

# Get access token
Write-Host ""
Write-Host "Getting access token..." -ForegroundColor Yellow
try {
    $TOKEN = gcloud auth print-access-token
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to get access token" -ForegroundColor Red
        exit 1
    }
    Write-Host "Access token obtained" -ForegroundColor Green
} catch {
    Write-Host "Error getting token: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Read OpenAPI spec
Write-Host ""
Write-Host "Reading OpenAPI specification..." -ForegroundColor Yellow
$openApiPath = "openapi/odin-openapi.yaml"
if (-not (Test-Path $openApiPath)) {
    Write-Host "OpenAPI file not found: $openApiPath" -ForegroundColor Red
    exit 1
}

$openApiContent = Get-Content $openApiPath -Raw
Write-Host "OpenAPI spec loaded ($(($openApiContent | Measure-Object -Character).Characters) characters)" -ForegroundColor Green

# Prepare connector configuration
$connectorConfig = @{
    name = "projects/$ProjectId/locations/$Region/customConnectors/$ConnectorName"
    displayName = "ODIN Secure Communication"
    description = "Custom connector for ODIN AI-to-AI secure communication protocol"
    connectorInfraConfig = @{
        runtimeEndpoint = $BaseUrl
    }
    authConfig = @{
        authType = "GOOGLE_ID_TOKEN"
        googleIdToken = @{
            serviceAccount = $ServiceAccount
            audience = $BaseUrl
        }
    }
    customConnectorType = "CUSTOM"
    customConnectorVersion = "1"
} | ConvertTo-Json -Depth 10

Write-Host ""
Write-Host "Connector configuration prepared" -ForegroundColor Green

# API endpoint for creating custom connector
$apiUrl = "https://connectors.googleapis.com/v1/projects/$ProjectId/locations/$Region/customConnectors?customConnectorId=$ConnectorName"

Write-Host ""
Write-Host "API URL: $apiUrl" -ForegroundColor White

# Prepare headers
$headers = @{
    "Authorization" = "Bearer $TOKEN"
    "Content-Type" = "application/json"
    "User-Agent" = "ODIN-Connector-Deploy/1.0"
}

Write-Host ""
Write-Host "Attempting to create custom connector via REST API..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $connectorConfig
    Write-Host "Custom connector created successfully!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor White
    $response | ConvertTo-Json -Depth 5
} catch {
    Write-Host "REST API call failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        try {
            $errorDetails = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorDetails)
            $errorBody = $reader.ReadToEnd()
            Write-Host "Error Details: $errorBody" -ForegroundColor Red
        } catch {
            Write-Host "Could not read error details" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "REST API deployment failed. Falling back to alternative methods..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Alternative Deployment Options:" -ForegroundColor Yellow
Write-Host "1. Manual Console UI (recommended): Use the browser pages we opened" -ForegroundColor White
Write-Host "2. Cloud Shell: Use Google Cloud Shell with web interface" -ForegroundColor White
Write-Host "3. Python/curl script: Direct HTTP calls with better error handling" -ForegroundColor White
Write-Host "4. GitHub Actions: Automated deployment on code push" -ForegroundColor White
