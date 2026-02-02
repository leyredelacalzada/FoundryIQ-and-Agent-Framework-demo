#!/bin/bash
#
# Setup RBAC for FoundryIQ + Agent Framework Demo
#
# Required roles for Users and Managed Identities:
# - Cognitive Services OpenAI User (for RBAC-only OpenAI access)
# - Cognitive Services User (general access)
# - Azure AI Developer (Foundry Agents API)
# - Search Index Data Reader/Contributor
# - Search Service Contributor
# - Storage Blob Data Reader
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_step() { echo ""; echo "=== $1 ==="; echo ""; }
}

RESOURCE_GROUP="${1:-${AZURE_RESOURCE_GROUP:-${RG_NAME:-}}}"
SUBSCRIPTION_ID="${2:-${AZURE_SUBSCRIPTION_ID:-}}"

if [ -z "$RESOURCE_GROUP" ]; then
    RESOURCE_GROUP=$(az group list --query "[?contains(name,'fiq')].name" -o tsv | head -1)
fi
if [ -z "$SUBSCRIPTION_ID" ]; then
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

# Role IDs
COGNITIVE_SERVICES_OPENAI_USER="5e0bd9bd-7b93-4f28-af87-19fc36ad61bd"
COGNITIVE_SERVICES_USER="a97b65f3-24c7-4388-baec-2e87135dc908"
AZURE_AI_DEVELOPER="64702f94-c441-49e6-a78b-ef80e0188fee"
SEARCH_INDEX_DATA_READER="1407120a-92aa-4202-b7e9-c0e197c71c8f"
SEARCH_INDEX_DATA_CONTRIBUTOR="8ebe5a00-799e-43f5-93ac-243d3dce84a7"
SEARCH_SERVICE_CONTRIBUTOR="7ca78c08-252a-4471-8644-bb5ff32d4ba0"
STORAGE_BLOB_DATA_READER="2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"

log_step "Setting up RBAC for FoundryIQ + Agent Framework"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Subscription: ${SUBSCRIPTION_ID}"

az account set --subscription "${SUBSCRIPTION_ID}"

# Get current user
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
[ -n "${CURRENT_USER_ID}" ] && echo "Current User: ${CURRENT_USER_ID}"

# Get resource IDs
FOUNDRY_HUB_ID=$(az cognitiveservices account list -g "${RESOURCE_GROUP}" \
    --query "[?kind=='AIServices'].id | [0]" -o tsv 2>/dev/null)
FOUNDRY_PROJECT_ID=$(az resource list -g "${RESOURCE_GROUP}" \
    --resource-type "Microsoft.CognitiveServices/accounts" \
    --query "[?contains(name,'proj')].id | [0]" -o tsv 2>/dev/null)
OPENAI_ID=$(az cognitiveservices account list -g "${RESOURCE_GROUP}" \
    --query "[?kind=='OpenAI'].id | [0]" -o tsv 2>/dev/null)
SEARCH_SERVICE_ID=$(az search service list -g "${RESOURCE_GROUP}" --query "[0].id" -o tsv 2>/dev/null)
SEARCH_SERVICE_NAME=$(az search service list -g "${RESOURCE_GROUP}" --query "[0].name" -o tsv 2>/dev/null)
STORAGE_ID=$(az storage account list -g "${RESOURCE_GROUP}" --query "[0].id" -o tsv 2>/dev/null)

# Get managed identities
SEARCH_MI=$(az search service show -g "${RESOURCE_GROUP}" -n "${SEARCH_SERVICE_NAME}" \
    --query "identity.principalId" -o tsv 2>/dev/null || echo "")
HUB_MI=$(az cognitiveservices account show -n "${FOUNDRY_HUB_ID##*/}" -g "${RESOURCE_GROUP}" \
    --query "identity.principalId" -o tsv 2>/dev/null || echo "")
UAMI_ID=$(az identity list -g "${RESOURCE_GROUP}" --query "[0].principalId" -o tsv 2>/dev/null || echo "")

echo "Foundry Hub: ${FOUNDRY_HUB_ID##*/}"
echo "Search: ${SEARCH_SERVICE_NAME}"

assign_role() {
    local SCOPE="$1" ROLE="$2" PRINCIPAL="$3" TYPE="$4" DESC="$5"
    echo -n "   ${DESC}... "
    if az role assignment create --scope "${SCOPE}" --role "${ROLE}" \
        --assignee-object-id "${PRINCIPAL}" --assignee-principal-type "${TYPE}" \
        --output none 2>/dev/null; then echo "✓"
    else echo "✓ (exists)"; fi
}

# User roles
if [ -n "${CURRENT_USER_ID}" ]; then
    echo ""; echo "👤 User roles..."
    assign_role "${FOUNDRY_HUB_ID}" "${COGNITIVE_SERVICES_OPENAI_USER}" "${CURRENT_USER_ID}" "User" "OpenAI User on Hub"
    assign_role "${FOUNDRY_HUB_ID}" "${COGNITIVE_SERVICES_USER}" "${CURRENT_USER_ID}" "User" "Cog Services User on Hub"
    assign_role "${FOUNDRY_HUB_ID}" "${AZURE_AI_DEVELOPER}" "${CURRENT_USER_ID}" "User" "AI Developer on Hub"
    [ -n "${FOUNDRY_PROJECT_ID}" ] && assign_role "${FOUNDRY_PROJECT_ID}" "${COGNITIVE_SERVICES_OPENAI_USER}" "${CURRENT_USER_ID}" "User" "OpenAI User on Project"
    [ -n "${FOUNDRY_PROJECT_ID}" ] && assign_role "${FOUNDRY_PROJECT_ID}" "${AZURE_AI_DEVELOPER}" "${CURRENT_USER_ID}" "User" "AI Developer on Project"
    [ -n "${OPENAI_ID}" ] && assign_role "${OPENAI_ID}" "${COGNITIVE_SERVICES_OPENAI_USER}" "${CURRENT_USER_ID}" "User" "OpenAI User on OAI"
    assign_role "${SEARCH_SERVICE_ID}" "${SEARCH_INDEX_DATA_READER}" "${CURRENT_USER_ID}" "User" "Search Reader"
    assign_role "${SEARCH_SERVICE_ID}" "${SEARCH_INDEX_DATA_CONTRIBUTOR}" "${CURRENT_USER_ID}" "User" "Search Contributor"
    assign_role "${SEARCH_SERVICE_ID}" "${SEARCH_SERVICE_CONTRIBUTOR}" "${CURRENT_USER_ID}" "User" "Search Svc Contributor"
    [ -n "${STORAGE_ID}" ] && assign_role "${STORAGE_ID}" "${STORAGE_BLOB_DATA_READER}" "${CURRENT_USER_ID}" "User" "Storage Reader"
fi

# Search MI roles (for KB model access)
if [ -n "${SEARCH_MI}" ]; then
    echo ""; echo "🔍 Search MI roles..."
    assign_role "${FOUNDRY_HUB_ID}" "${COGNITIVE_SERVICES_OPENAI_USER}" "${SEARCH_MI}" "ServicePrincipal" "OpenAI User on Hub"
    [ -n "${OPENAI_ID}" ] && assign_role "${OPENAI_ID}" "${COGNITIVE_SERVICES_OPENAI_USER}" "${SEARCH_MI}" "ServicePrincipal" "OpenAI User on OAI"
    [ -n "${STORAGE_ID}" ] && assign_role "${STORAGE_ID}" "${STORAGE_BLOB_DATA_READER}" "${SEARCH_MI}" "ServicePrincipal" "Storage Reader"
fi

# Hub MI roles
if [ -n "${HUB_MI}" ]; then
    echo ""; echo "🤖 Hub MI roles..."
    assign_role "${SEARCH_SERVICE_ID}" "${SEARCH_INDEX_DATA_READER}" "${HUB_MI}" "ServicePrincipal" "Search Reader"
    assign_role "${SEARCH_SERVICE_ID}" "${SEARCH_INDEX_DATA_CONTRIBUTOR}" "${HUB_MI}" "ServicePrincipal" "Search Contributor"
    [ -n "${STORAGE_ID}" ] && assign_role "${STORAGE_ID}" "${STORAGE_BLOB_DATA_READER}" "${HUB_MI}" "ServicePrincipal" "Storage Reader"
fi

# UAMI roles
if [ -n "${UAMI_ID}" ]; then
    echo ""; echo "🔑 UAMI roles..."
    assign_role "${FOUNDRY_HUB_ID}" "${COGNITIVE_SERVICES_OPENAI_USER}" "${UAMI_ID}" "ServicePrincipal" "OpenAI User on Hub"
    assign_role "${FOUNDRY_HUB_ID}" "${AZURE_AI_DEVELOPER}" "${UAMI_ID}" "ServicePrincipal" "AI Developer on Hub"
    assign_role "${SEARCH_SERVICE_ID}" "${SEARCH_INDEX_DATA_READER}" "${UAMI_ID}" "ServicePrincipal" "Search Reader"
    assign_role "${SEARCH_SERVICE_ID}" "${SEARCH_INDEX_DATA_CONTRIBUTOR}" "${UAMI_ID}" "ServicePrincipal" "Search Contributor"
    [ -n "${STORAGE_ID}" ] && assign_role "${STORAGE_ID}" "${STORAGE_BLOB_DATA_READER}" "${UAMI_ID}" "ServicePrincipal" "Storage Reader"
fi

echo ""
log_success "RBAC setup complete! Roles may take 2-5 minutes to propagate."
echo ""
echo "Reminder: Ensure Search service has RBAC enabled:"
echo "  Portal → ${SEARCH_SERVICE_NAME} → Keys → API Access control → 'Both'"
