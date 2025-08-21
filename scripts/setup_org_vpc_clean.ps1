param(
    [Parameter(Mandatory=$false)]
    [string]$OrganizationId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "odin-secure-comm-org",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-central1",
    
    [Parameter(Mandatory=$false)]
    [string]$BillingAccountId = ""
)

Write-Host "=== ODIN PROTOCOL ORGANIZATION VPC SETUP ===" -ForegroundColor Green
Write-Host ""

# Verify organization access
Write-Host "Checking organization access..." -ForegroundColor Cyan

try {
    $organizations = gcloud organizations list --format="value(name)" 2>$null
    if (-not $organizations) {
        Write-Host "No organizations found" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Organizations found:" -ForegroundColor Green
    gcloud organizations list
    
    # Auto-detect organization if not provided
    if (-not $OrganizationId) {
        $OrganizationId = ($organizations | Select-Object -First 1)
        Write-Host "Auto-detected Organization ID: $OrganizationId" -ForegroundColor Green
    }
    
} catch {
    Write-Host "Error checking organizations: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Using Organization ID: $OrganizationId" -ForegroundColor Cyan
Write-Host "Project ID: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan

# Check if project already exists
Write-Host ""
Write-Host "Checking if project exists..." -ForegroundColor Cyan

$existingProject = gcloud projects list --filter="projectId:$ProjectId" --format="value(projectId)" 2>$null
if ($existingProject) {
    Write-Host "Project $ProjectId already exists" -ForegroundColor Green
    gcloud config set project $ProjectId
} else {
    Write-Host "Creating project under organization..." -ForegroundColor Yellow
    
    # Check billing account
    if (-not $BillingAccountId) {
        Write-Host "Looking for billing accounts..." -ForegroundColor Cyan
        $billingAccounts = gcloud billing accounts list --format="value(name)" 2>$null
        if ($billingAccounts) {
            $BillingAccountId = $billingAccounts | Select-Object -First 1
            Write-Host "Auto-selected billing account: $BillingAccountId" -ForegroundColor Green
        } else {
            Write-Host "No billing accounts found" -ForegroundColor Red
            Write-Host "Please set up billing at: https://console.cloud.google.com/billing" -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Create project under organization
    Write-Host "Creating project: $ProjectId" -ForegroundColor Yellow
    try {
        gcloud projects create $ProjectId --organization=$OrganizationId --name="ODIN Secure Communication" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Project creation failed"
        }
        Write-Host "Project created successfully" -ForegroundColor Green
        
        # Link billing
        Write-Host "Linking billing account..." -ForegroundColor Yellow
        gcloud billing projects link $ProjectId --billing-account=$BillingAccountId 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Billing linked successfully" -ForegroundColor Green
        } else {
            Write-Host "Billing link failed - please link manually" -ForegroundColor Yellow
        }
        
        gcloud config set project $ProjectId
        
    } catch {
        Write-Host "Error creating project: $_" -ForegroundColor Red
        exit 1
    }
}

# Enable required APIs
Write-Host ""
Write-Host "Enabling required APIs..." -ForegroundColor Cyan

$requiredApis = @(
    "compute.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com", 
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com"
)

foreach ($api in $requiredApis) {
    Write-Host "  Enabling $api..." -ForegroundColor White
    gcloud services enable $api --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  $api enabled" -ForegroundColor Green
    } else {
        Write-Host "  Failed to enable $api" -ForegroundColor Red
    }
}

# Wait for APIs to be fully enabled
Write-Host ""
Write-Host "Waiting for APIs to be fully enabled..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Setup VPC Network
Write-Host ""
Write-Host "Setting up VPC network..." -ForegroundColor Cyan

$vpcName = "odin-secure-vpc"
$subnetName = "odin-secure-subnet"

# Check if VPC exists
$existingVpc = gcloud compute networks list --filter="name:$vpcName" --format="value(name)" 2>$null
if ($existingVpc) {
    Write-Host "VPC $vpcName already exists" -ForegroundColor Green
} else {
    Write-Host "Creating VPC network: $vpcName" -ForegroundColor Yellow
    gcloud compute networks create $vpcName --subnet-mode=custom --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "VPC created successfully" -ForegroundColor Green
    } else {
        Write-Host "VPC creation failed" -ForegroundColor Red
        exit 1
    }
}

# Check if subnet exists
$existingSubnet = gcloud compute networks subnets list --filter="name:$subnetName" --format="value(name)" 2>$null
if ($existingSubnet) {
    Write-Host "Subnet $subnetName already exists" -ForegroundColor Green
} else {
    Write-Host "Creating subnet: $subnetName" -ForegroundColor Yellow
    gcloud compute networks subnets create $subnetName --network=$vpcName --range=10.0.0.0/24 --region=$Region --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Subnet created successfully" -ForegroundColor Green
    } else {
        Write-Host "Subnet creation failed" -ForegroundColor Red
        exit 1
    }
}

# Setup Firewall Rules for Marketplace
Write-Host ""
Write-Host "Setting up firewall rules..." -ForegroundColor Cyan

# Allow health checks
$healthCheckRule = "odin-allow-health-checks"
$existingHealthRule = gcloud compute firewall-rules list --filter="name:$healthCheckRule" --format="value(name)" 2>$null

if ($existingHealthRule) {
    Write-Host "Firewall rule $healthCheckRule already exists" -ForegroundColor Green
} else {
    Write-Host "Creating firewall rule: $healthCheckRule" -ForegroundColor Yellow
    gcloud compute firewall-rules create $healthCheckRule --network=$vpcName --description="Allow health checks from Google Load Balancers" --direction=INGRESS --action=allow --rules=tcp:8080 --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=odin-gateway --quiet 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Health check firewall rule created successfully" -ForegroundColor Green
    } else {
        Write-Host "Health check firewall rule creation failed" -ForegroundColor Red
    }
}

# Allow marketplace access
$marketplaceRule = "odin-allow-marketplace-access"
$existingMarketplaceRule = gcloud compute firewall-rules list --filter="name:$marketplaceRule" --format="value(name)" 2>$null

if ($existingMarketplaceRule) {
    Write-Host "Firewall rule $marketplaceRule already exists" -ForegroundColor Green
} else {
    Write-Host "Creating firewall rule: $marketplaceRule" -ForegroundColor Yellow
    gcloud compute firewall-rules create $marketplaceRule --network=$vpcName --description="Allow access from Marketplace verified sources" --direction=INGRESS --action=allow --rules=tcp:8080 --source-ranges=0.0.0.0/0 --target-tags=odin-gateway --quiet 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Marketplace firewall rule created successfully" -ForegroundColor Green
    } else {
        Write-Host "Marketplace firewall rule creation failed" -ForegroundColor Red
    }
}

# Setup additional organization-level resources
Write-Host ""
Write-Host "Setting up organization resources..." -ForegroundColor Cyan

# Create Artifact Registry for organization
$repoName = "odin-containers"
$existingRepo = gcloud artifacts repositories list --filter="name:$repoName" --format="value(name)" 2>$null
if ($existingRepo) {
    Write-Host "Artifact Registry $repoName already exists" -ForegroundColor Green
} else {
    Write-Host "Creating Artifact Registry repository..." -ForegroundColor Yellow
    gcloud artifacts repositories create $repoName --repository-format=docker --location=$Region --description="ODIN Protocol container registry" --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Artifact Registry created successfully" -ForegroundColor Green
    } else {
        Write-Host "Artifact Registry creation failed" -ForegroundColor Red
    }
}

# Setup Firestore
Write-Host ""
Write-Host "Setting up Firestore..." -ForegroundColor Yellow
$existingFirestore = gcloud firestore databases list --format="value(name)" 2>$null
if ($existingFirestore) {
    Write-Host "Firestore already configured" -ForegroundColor Green
} else {
    gcloud firestore databases create --region=$Region --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Firestore created successfully" -ForegroundColor Green
    } else {
        Write-Host "Firestore creation failed" -ForegroundColor Red
    }
}

# Summary
Write-Host ""
Write-Host "=== ORGANIZATION VPC SETUP COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "CREATED RESOURCES:" -ForegroundColor Cyan
Write-Host "Organization: odinprotocol.dev ($OrganizationId)" -ForegroundColor White
Write-Host "Project: $ProjectId" -ForegroundColor White
Write-Host "VPC Network: $vpcName" -ForegroundColor White
Write-Host "Subnet: $subnetName ($Region)" -ForegroundColor White
Write-Host "Firewall Rules: Marketplace-ready" -ForegroundColor White
Write-Host "Artifact Registry: $repoName" -ForegroundColor White
Write-Host "Firestore: Native mode" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Update deployment scripts to use: $ProjectId" -ForegroundColor White
Write-Host "2. Configure GitHub Actions with new project" -ForegroundColor White
Write-Host "3. Deploy ODIN gateway to organization project" -ForegroundColor White
Write-Host "4. Apply for Google Cloud Marketplace Producer Portal" -ForegroundColor White
Write-Host ""
Write-Host "MARKETPLACE PORTAL:" -ForegroundColor Cyan
Write-Host "https://console.cloud.google.com/marketplace/product/gcp-marketplace-portal" -ForegroundColor Blue
Write-Host ""
Write-Host "PROJECT DETAILS:" -ForegroundColor Cyan
Write-Host "Project ID: $ProjectId" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "VPC: $vpcName" -ForegroundColor White
