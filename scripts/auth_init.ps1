# Authentication initialization script
# This script is called by azd during preprovision

Write-Host "Initializing authentication..."

# Check if authentication is enabled
if ($env:AZURE_USE_AUTHENTICATION -ne "true") {
    Write-Host "Authentication is not enabled. Skipping auth initialization."
    exit 0
}

# Ensure required variables are set
if ([string]::IsNullOrEmpty($env:AZURE_AUTH_TENANT_ID)) {
    Write-Host "Error: AZURE_AUTH_TENANT_ID is required when authentication is enabled."
    exit 1
}

Write-Host "Auth initialization complete."
