#!/bin/bash
# Authentication initialization script
# This script is called by azd during preprovision

echo "Initializing authentication..."

# Check if authentication is enabled
if [ "$AZURE_USE_AUTHENTICATION" != "true" ]; then
    echo "Authentication is not enabled. Skipping auth initialization."
    exit 0
fi

# Ensure required variables are set
if [ -z "$AZURE_AUTH_TENANT_ID" ]; then
    echo "Error: AZURE_AUTH_TENANT_ID is required when authentication is enabled."
    exit 1
fi

echo "Auth initialization complete."
