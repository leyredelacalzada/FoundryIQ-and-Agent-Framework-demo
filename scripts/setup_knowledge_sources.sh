#!/bin/bash
#
# Setup Knowledge Sources
# Creates all FoundryIQ knowledge sources (searchIndex, web types)
# NOTE: Azure Blob KS requires portal creation with UAMI (see MANUAL_STEPS.md)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_step() { echo ""; echo "=== $1 ==="; echo ""; }
}

log_step "Creating Knowledge Sources"

API_VERSION="2025-11-01-preview"

# Create knowledge source
create_ks() {
    local name=$1
    local payload=$2
    
    log_info "Creating knowledge source: $name"
    
    HTTP_CODE=$(curl -s -o /tmp/ks_response.json -w "%{http_code}" \
        -X PUT "${SEARCH_ENDPOINT}/knowledgesources/${name}?api-version=${API_VERSION}" \
        -H "api-key: ${SEARCH_KEY}" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        log_success "Created knowledge source: $name"
    else
        log_warn "KS $name may already exist or error (HTTP $HTTP_CODE)"
        if [ "$VERBOSE" = true ]; then
            cat /tmp/ks_response.json
        fi
    fi
}

# 1. Search Index Knowledge Sources (matching portal-created names)
log_info "Creating AI Search index-based knowledge sources..."

# HR Knowledge Sources
create_ks "ks-hr-sharepoint" '{
    "name": "ks-hr-sharepoint",
    "kind": "searchIndex",
    "description": "HR documents from SharePoint (indexed in AI Search)",
    "searchIndexParameters": {
        "searchIndexName": "index-hr"
    }
}'

create_ks "ks-hr-aisearch" '{
    "name": "ks-hr-aisearch",
    "kind": "searchIndex",
    "description": "HR policies from AI Search index",
    "searchIndexParameters": {
        "searchIndexName": "index-hr"
    }
}'

# Products Knowledge Source
create_ks "ks-products" '{
    "name": "ks-products",
    "kind": "searchIndex",
    "description": "Product catalog with specifications and pricing from AI Search index",
    "searchIndexParameters": {
        "searchIndexName": "index-products"
    }
}'

# Marketing Knowledge Source
create_ks "ks-marketing" '{
    "name": "ks-marketing",
    "kind": "searchIndex",
    "description": "Marketing campaigns, content, and analytics from AI Search index",
    "searchIndexParameters": {
        "searchIndexName": "index-marketing"
    }
}'

# 2. Web Knowledge Sources (Remote)
log_info "Creating Web knowledge sources..."

create_ks "ks-hr-web" '{
    "name": "ks-hr-web",
    "kind": "web",
    "description": "Remote HR resources from trusted web sources",
    "webParameters": {
        "allowedDomains": [
            {"address": "https://www.shrm.org", "includeSubpages": true},
            {"address": "https://www.dol.gov", "includeSubpages": true},
            {"address": "https://www.eeoc.gov", "includeSubpages": true}
        ]
    }
}'

create_ks "ks-marketing-web" '{
    "name": "ks-marketing-web",
    "kind": "web",
    "description": "Remote marketing resources from trusted web sources",
    "webParameters": {
        "allowedDomains": [
            {"address": "https://blog.hubspot.com", "includeSubpages": true},
            {"address": "https://neilpatel.com", "includeSubpages": true},
            {"address": "https://contentmarketinginstitute.com", "includeSubpages": true}
        ]
    }
}'

# 3. Azure Blob Knowledge Source - REQUIRES PORTAL CREATION
log_warn "Azure Blob Knowledge Source (ks-blob-marketing) requires portal creation!"
log_warn "See docs/MANUAL_STEPS.md for instructions."
log_info "Reason: Shared key access may be disabled, requiring UAMI authentication via portal"

# 4. OneLake Knowledge Source - REQUIRES FABRIC SETUP
if [ "$SKIP_ONELAKE_KS" = true ]; then
    log_warn "Skipping OneLake knowledge source (--skip-onelake-ks)"
else
    log_warn "OneLake Knowledge Source (ks-products-onelake) requires:"
    log_warn "  1. Fabric capacity and workspace created"
    log_warn "  2. UAMI added to OneLake security in Fabric portal"
    log_warn "See docs/MANUAL_STEPS.md for instructions."
    
    # If Fabric environment variables are set, attempt creation
    if [ -n "$FABRIC_WORKSPACE_ID" ] && [ -n "$LAKEHOUSE_ID" ]; then
        log_info "Creating OneLake knowledge source..."
        
        create_ks "ks-products-onelake" "{
            \"name\": \"ks-products-onelake\",
            \"kind\": \"indexedOneLake\",
            \"description\": \"Product catalog from Fabric Lakehouse\",
            \"indexedOneLakeParameters\": {
                \"fabricWorkspaceId\": \"${FABRIC_WORKSPACE_ID}\",
                \"lakehouseId\": \"${LAKEHOUSE_ID}\",
                \"targetPath\": \"/Files/products\"
            },
            \"ingestionParameters\": {
                \"identity\": {
                    \"@odata.type\": \"#Microsoft.Azure.Search.SearchIndexerDataUserAssignedIdentity\",
                    \"userAssignedIdentity\": \"${UAMI_RESOURCE_ID}\"
                },
                \"disableImageVerbalization\": true,
                \"contentExtractionMode\": \"minimal\",
                \"embeddingModel\": {
                    \"kind\": \"azureOpenAI\",
                    \"azureOpenAIParameters\": {
                        \"resourceUri\": \"${OPENAI_ENDPOINT}\",
                        \"deploymentId\": \"text-embedding-3-large\",
                        \"modelName\": \"text-embedding-3-large\"
                    }
                }
            }
        }"
    fi
fi

log_success "Knowledge sources setup complete"
echo ""
log_info "Summary of Knowledge Sources:"
echo "  ✅ ks-hr-sharepoint (searchIndex) → index-hr"
echo "  ✅ ks-hr-aisearch (searchIndex) → index-hr"
echo "  ✅ ks-products (searchIndex) → index-products"
echo "  ✅ ks-marketing (searchIndex) → index-marketing"
echo "  ✅ ks-hr-web (web)"
echo "  ✅ ks-marketing-web (web)"
echo "  ⚠️  ks-blob-marketing (azureBlob) - MANUAL PORTAL CREATION REQUIRED"
echo "  ⚠️  ks-products-onelake (indexedOneLake) - REQUIRES FABRIC + MANUAL SECURITY"
