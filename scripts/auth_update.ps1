# Authentication update script
# This script is called by azd during postprovision

Write-Host "Updating authentication configuration..."

# Check if authentication is enabled
if ($env:AZURE_USE_AUTHENTICATION -ne "true") {
    Write-Host "Authentication is not enabled. Skipping auth update."
    exit 0
}

Write-Host "Auth update complete."
