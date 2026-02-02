#!/bin/bash
#
# Setup OpenAI Model Deployments for FoundryIQ + Agent Framework Demo
#
# This script deploys the required OpenAI models to the Azure AI Foundry Hub.
# The gpt-4o model is required for both:
# - Agent inference (chat completions)
# - Agentic retrieval mode in FoundryIQ
#
# Usage: ./setup_openai_deployments.sh [resource_group] [subscription_id]

set -e

# Configuration (can be overridden by environment variables)
RESOURCE_GROUP="${1:-${AZURE_RESOURCE_GROUP:-rg-fiq-maf-demo}}"
SUBSCRIPTION_ID="${2:-${AZURE_SUBSCRIPTION_ID:-c8b040a6-1c00-4648-8a52-53351279e1f7}}"

# Model configuration
MODEL_NAME="gpt-4o"
MODEL_VERSION="2024-11-20"
MODEL_FORMAT="OpenAI"
MODEL_SKU="Standard"
MODEL_CAPACITY="10"  # TPM in thousands (10 = 10K TPM)

echo "=============================================="
echo "Setting up OpenAI Model Deployments"
echo "=============================================="
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Subscription: ${SUBSCRIPTION_ID}"
echo "Model: ${MODEL_NAME} (version ${MODEL_VERSION})"
echo ""

# Set subscription
az account set --subscription "${SUBSCRIPTION_ID}"

# Find the Azure AI Foundry Hub (Cognitive Services account of kind AIServices)
echo "📋 Finding Azure AI Foundry Hub..."
FOUNDRY_HUB_NAME=$(az resource list \
    --resource-group "${RESOURCE_GROUP}" \
    --resource-type "Microsoft.CognitiveServices/accounts" \
    --query "[?kind=='AIServices'].name | [0]" -o tsv 2>/dev/null)

if [ -z "${FOUNDRY_HUB_NAME}" ]; then
    echo "❌ Azure AI Foundry Hub not found in resource group ${RESOURCE_GROUP}"
    exit 1
fi
echo "   Found Hub: ${FOUNDRY_HUB_NAME}"

# Check if deployment already exists
echo ""
echo "📋 Checking existing deployments..."
EXISTING_DEPLOYMENT=$(az cognitiveservices account deployment list \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${FOUNDRY_HUB_NAME}" \
    --query "[?name=='${MODEL_NAME}'].name | [0]" -o tsv 2>/dev/null || echo "")

if [ -n "${EXISTING_DEPLOYMENT}" ]; then
    echo "   ✓ Deployment '${MODEL_NAME}' already exists"
    
    # Show deployment details
    az cognitiveservices account deployment show \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${FOUNDRY_HUB_NAME}" \
        --deployment-name "${MODEL_NAME}" \
        --query "{name:name, model:properties.model.name, version:properties.model.version, sku:sku.name}" \
        -o table
else
    echo "   Deployment '${MODEL_NAME}' not found, creating..."
    echo ""
    echo "🚀 Deploying ${MODEL_NAME}..."
    
    # Deploy the model using REST API (more reliable than CLI for deployments)
    ENDPOINT="https://management.azure.com"
    ACCOUNT_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY_HUB_NAME}"
    DEPLOYMENT_PATH="${ACCOUNT_ID}/deployments/${MODEL_NAME}?api-version=2024-10-01"
    
    # Get access token
    TOKEN=$(az account get-access-token --query accessToken -o tsv)
    
    # Create deployment
    RESULT=$(curl -s -X PUT "${ENDPOINT}${DEPLOYMENT_PATH}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"sku\": {
                \"name\": \"${MODEL_SKU}\",
                \"capacity\": ${MODEL_CAPACITY}
            },
            \"properties\": {
                \"model\": {
                    \"format\": \"${MODEL_FORMAT}\",
                    \"name\": \"${MODEL_NAME}\",
                    \"version\": \"${MODEL_VERSION}\"
                }
            }
        }")
    
    # Check result
    if echo "${RESULT}" | grep -q '"provisioningState"'; then
        echo "   ✓ Deployment created successfully"
        echo "${RESULT}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"   Status: {d.get('properties',{}).get('provisioningState','unknown')}\")"
    else
        echo "   ⚠️ Deployment response:"
        echo "${RESULT}" | python3 -m json.tool 2>/dev/null || echo "${RESULT}"
    fi
fi

echo ""
echo "=============================================="
echo "✅ OpenAI Deployment Setup Complete!"
echo "=============================================="
echo ""
echo "Deployed model:"
echo "  • Name: ${MODEL_NAME}"
echo "  • Version: ${MODEL_VERSION}"
echo "  • SKU: ${MODEL_SKU}"
echo "  • Capacity: ${MODEL_CAPACITY}K TPM"
echo ""
echo "This model is used for:"
echo "  • Agent inference (chat completions)"
echo "  • FoundryIQ agentic retrieval mode"
echo ""
