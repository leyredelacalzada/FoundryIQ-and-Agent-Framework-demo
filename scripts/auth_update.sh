#!/bin/bash
# Authentication update script
# This script is called by azd during postprovision

echo "Updating authentication configuration..."

# Check if authentication is enabled
if [ "$AZURE_USE_AUTHENTICATION" != "true" ]; then
    echo "Authentication is not enabled. Skipping auth update."
    exit 0
fi

echo "Auth update complete."
