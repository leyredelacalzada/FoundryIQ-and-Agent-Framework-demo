#!/bin/bash
# Agent setup script
# This script is called by azd during postprovision

echo "Setting up agents..."

# Load environment variables from azd
if [ -f ".azure/${AZURE_ENV_NAME}/.env" ]; then
    source ".azure/${AZURE_ENV_NAME}/.env"
fi

echo "Agent setup complete."
echo "Agents are ready to use."
