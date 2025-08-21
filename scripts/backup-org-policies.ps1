# ODIN Organizational Policy Backup
# Backup current organizational policies before clearing them

param(
    [string]$OrganizationId = "785932421130",
    [string]$BackupDir = "backup/org-policies"
)

Write-Host "ODIN Organizational Policy Backup" -ForegroundColor Green
Write-Host "Organization: $OrganizationId" -ForegroundColor Cyan
Write-Host "Backup Directory: $BackupDir" -ForegroundColor Cyan

# Create backup directory
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Host "Created backup directory: $BackupDir" -ForegroundColor Green
}

# Get timestamp for backup files
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = "$BackupDir/org-policies-$timestamp.json"

Write-Host ""
Write-Host "Backing up all organizational policies..." -ForegroundColor Yellow

try {
    # Get all policies in JSON format
    $allPolicies = gcloud resource-manager org-policies list --organization=$OrganizationId --format=json | ConvertFrom-Json
    
    if ($allPolicies.Count -gt 0) {
        Write-Host "Found $($allPolicies.Count) organizational policies" -ForegroundColor White
        
        $backupData = @{
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            organization = $OrganizationId
            policies = @()
        }
        
        foreach ($policy in $allPolicies) {
            Write-Host "Backing up: $($policy.constraint)" -ForegroundColor White
            
            try {
                # Get detailed policy configuration
                $policyDetail = gcloud resource-manager org-policies describe $policy.constraint --organization=$OrganizationId --format=json | ConvertFrom-Json
                $backupData.policies += $policyDetail
            } catch {
                Write-Host "  Warning: Could not backup $($policy.constraint)" -ForegroundColor Yellow
            }
        }
        
        # Save backup to file
        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Host ""
        Write-Host "Backup saved to: $backupFile" -ForegroundColor Green
        Write-Host "Backup contains $($backupData.policies.Count) policy details" -ForegroundColor White
        
    } else {
        Write-Host "No organizational policies found to backup" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "Error during backup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Backup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the backup file: $backupFile" -ForegroundColor White
Write-Host "2. Clear policies (dry run): .\scripts\clear-org-policies.ps1 -DryRun" -ForegroundColor White
Write-Host "3. Clear policies (actual): .\scripts\clear-org-policies.ps1" -ForegroundColor White
Write-Host "4. Deploy connector via console or API" -ForegroundColor White
Write-Host "5. Restore policies when done (manual process)" -ForegroundColor White
