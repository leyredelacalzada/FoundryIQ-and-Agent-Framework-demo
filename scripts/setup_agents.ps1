# Agent setup script
# This script is called by azd during postprovision

Write-Host "Setting up agents..."

# Load environment variables from azd
$envFile = ".azure/$env:AZURE_ENV_NAME/.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
}

Write-Host "Agent setup complete."
Write-Host "Agents are ready to use."
