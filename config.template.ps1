# ODIN Secure Communication - Configuration Template
# Copy this file and fill in your actual values before running scripts

# Replace these placeholders with your actual values:

# GCP Project Configuration
GCP_PROJECT_ID="odin-ai-to"               # Your actual GCP project ID
REGION="us-central1"                      # e.g., "us-central1", "europe-west1"

# Artifact Registry and Service Names  
REPO_NAME="odin"                          # Artifact Registry repository name
SERVICE_NAME="odin-secure-comm"           # Cloud Run service name

# Workload Identity Federation
WIF_POOL_ID="github-pool"                 # WIF pool identifier
WIF_PROVIDER_ID="github-provider"         # WIF provider identifier
DEPLOYER_SA_NAME="odin-deployer"          # Deployer service account name

# GitHub Repository (for WIF setup)
GITHUB_ORG="Maverick0351a"                # Your GitHub organization/username
GITHUB_REPO="odin-secure-comm"            # Your GitHub repository name

# Usage Instructions:
# 1. Copy this file to config.ps1 (excluded from git)
# 2. Replace all placeholder values with your actual values
# 3. Source the config before running scripts:
#    . ./config.ps1
# 4. Run scripts with actual values:
#    pwsh scripts/gcloud_setup.ps1 -ProjectId $GCP_PROJECT_ID -Region $REGION -RepoName $REPO_NAME -ServiceName $SERVICE_NAME -DeployerSAName $DEPLOYER_SA_NAME

# Example GitHub secrets configuration:
# Navigate to: https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions
# Add these repository secrets:
# - GCP_PROJECT_ID: (your project ID)
# - GCP_REGION: (your region)  
# - GCP_ARTIFACT_REPO: (your repo name)
# - GCP_SERVICE_NAME: (your service name)
# - GCP_WIF_PROVIDER: (output from wif_setup.ps1)
# - GCP_DEPLOYER_SA: (output from wif_setup.ps1)
