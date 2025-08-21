# ODIN Integration Connectors Deployment Script
# This script deploys the complete ODIN Protocol Integration Connector to Google Cloud

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,
    
    [string]$Region = "us-central1",
    [string]$ConnectorName = "odin-protocol",
    [string]$ConnectionName = "odin-ai-communication",
    [string]$CloudRunServiceName = "odin-gateway",
    [switch]$SkipGatewayDeploy,
    [switch]$ValidateOnly
)

Write-Host "🚀 ODIN Integration Connectors Deployment" -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Connector: $ConnectorName" -ForegroundColor Cyan
Write-Host "Connection: $ConnectionName" -ForegroundColor Cyan

# Step 1: Validate prerequisites
Write-Host "`n📋 Step 1: Validating prerequisites..." -ForegroundColor Yellow

# Check if gcloud is authenticated
try {
    $currentProject = gcloud config get-value project 2>$null
    if ($currentProject -ne $ProjectId) {
        Write-Host "Setting active project to $ProjectId..." -ForegroundColor Blue
        gcloud config set project $ProjectId
    }
    Write-Host "✅ gcloud authenticated for project: $ProjectId" -ForegroundColor Green
} catch {
    Write-Host "❌ gcloud authentication failed. Please run: gcloud auth login" -ForegroundColor Red
    exit 1
}

# Check if required APIs are enabled
$requiredApis = @(
    "integrations.googleapis.com",
    "connectors.googleapis.com", 
    "run.googleapis.com",
    "firestore.googleapis.com",
    "secretmanager.googleapis.com"
)

Write-Host "Checking required APIs..." -ForegroundColor Blue
foreach ($api in $requiredApis) {
    $apiStatus = gcloud services list --enabled --filter="name:$api" --format="value(name)" 2>$null
    if ($apiStatus) {
        Write-Host "✅ API enabled: $api" -ForegroundColor Green
    } else {
        Write-Host "⏳ Enabling API: $api" -ForegroundColor Yellow
        gcloud services enable $api
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ API enabled: $api" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to enable API: $api" -ForegroundColor Red
            exit 1
        }
    }
}

# Step 2: Validate configurations
Write-Host "`n🔍 Step 2: Validating configurations..." -ForegroundColor Yellow

# Validate OpenAPI spec
Write-Host "Validating OpenAPI specification..." -ForegroundColor Blue
python scripts\validate_openapi.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ OpenAPI validation failed" -ForegroundColor Red
    exit 1
}

# Validate Terraform config
Write-Host "Validating Terraform configuration..." -ForegroundColor Blue
python scripts\validate_terraform.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform validation failed" -ForegroundColor Red
    exit 1
}

if ($ValidateOnly) {
    Write-Host "`n✅ Validation complete! Use -ValidateOnly:$false to proceed with deployment." -ForegroundColor Green
    exit 0
}

# Step 3: Deploy ODIN Gateway (if not skipped)
if (-not $SkipGatewayDeploy) {
    Write-Host "`n🏗️ Step 3: Deploying ODIN Gateway..." -ForegroundColor Yellow
    
    # Check if gateway is already deployed
    $existingService = gcloud run services list --filter="metadata.name:$CloudRunServiceName" --format="value(metadata.name)" --region=$Region 2>$null
    
    if ($existingService) {
        Write-Host "✅ ODIN Gateway already deployed: $CloudRunServiceName" -ForegroundColor Green
    } else {
        Write-Host "Deploying ODIN Gateway to Cloud Run..." -ForegroundColor Blue
        & .\scripts\deploy_cloudrun.ps1 -ProjectId $ProjectId -Region $Region -ServiceName $CloudRunServiceName
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Gateway deployment failed" -ForegroundColor Red
            exit 1
        }
        Write-Host "✅ ODIN Gateway deployed successfully" -ForegroundColor Green
    }
} else {
    Write-Host "`n⏭️ Step 3: Skipping Gateway deployment" -ForegroundColor Yellow
}

# Step 4: Deploy Integration Connector
Write-Host "`n🔌 Step 4: Deploying Integration Connector..." -ForegroundColor Yellow

# Check if terraform is available
$terraformAvailable = Get-Command terraform -ErrorAction SilentlyContinue
if (-not $terraformAvailable) {
    Write-Host "❌ Terraform not found. Please install Terraform or use gcloud commands manually." -ForegroundColor Red
    Write-Host "Manual deployment commands:" -ForegroundColor Yellow
    Write-Host "gcloud integration-connectors custom-connectors create $ConnectorName --location=$Region --openapi-spec-location=openapi/odin-connector.yaml" -ForegroundColor Cyan
    exit 1
}

# Initialize and apply Terraform
Push-Location terraform
try {
    Write-Host "Initializing Terraform..." -ForegroundColor Blue
    terraform init
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform init failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Planning Terraform deployment..." -ForegroundColor Blue
    terraform plan -var="project_id=$ProjectId" -var="region=$Region" -var="connector_name=$ConnectorName" -var="connection_name=$ConnectionName" -var="cloud_run_service_name=$CloudRunServiceName"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform plan failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Applying Terraform configuration..." -ForegroundColor Blue
    terraform apply -auto-approve -var="project_id=$ProjectId" -var="region=$Region" -var="connector_name=$ConnectorName" -var="connection_name=$ConnectionName" -var="cloud_run_service_name=$CloudRunServiceName"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Integration Connector deployed successfully" -ForegroundColor Green
        
        # Get outputs
        Write-Host "`n📋 Deployment Information:" -ForegroundColor Cyan
        terraform output
    } else {
        Write-Host "❌ Terraform apply failed" -ForegroundColor Red
        exit 1
    }
    
} finally {
    Pop-Location
}

# Step 5: Test the deployment
Write-Host "`n🧪 Step 5: Testing deployment..." -ForegroundColor Yellow

Write-Host "Running endpoint tests..." -ForegroundColor Blue
& .\scripts\test-endpoints.ps1 -ProjectId $ProjectId -Region $Region -ServiceName $CloudRunServiceName

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Endpoint tests passed" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some endpoint tests failed - check the logs" -ForegroundColor Yellow
}

# Step 6: Summary
Write-Host "`n🎉 Deployment Summary:" -ForegroundColor Green
Write-Host "✅ ODIN Gateway: https://$CloudRunServiceName-$(gcloud config get-value project 2>$null).run.app" -ForegroundColor Cyan
Write-Host "✅ Integration Connector: $ConnectorName" -ForegroundColor Cyan
Write-Host "✅ Connection: $ConnectionName" -ForegroundColor Cyan
Write-Host "✅ Project: $ProjectId" -ForegroundColor Cyan
Write-Host "✅ Region: $Region" -ForegroundColor Cyan

Write-Host "`n📖 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Test the connector in Google Cloud Console > Integration Connectors" -ForegroundColor White
Write-Host "2. Create workflows using the connector in Cloud Workflows or App Engine" -ForegroundColor White
Write-Host "3. Monitor usage in Cloud Logging and Cloud Monitoring" -ForegroundColor White
Write-Host "4. Review security settings and IAM permissions" -ForegroundColor White

Write-Host "`n🚀 ODIN Integration Connectors deployment complete!" -ForegroundColor Green
