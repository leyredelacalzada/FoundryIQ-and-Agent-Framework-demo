#!/bin/bash
#
# Setup Knowledge Bases
# Creates FoundryIQ knowledge bases that aggregate multiple knowledge sources
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_step() { echo ""; echo "=== $1 ==="; echo ""; }
}

log_step "Creating Knowledge Bases"

API_VERSION="2025-11-01-preview"

# Create knowledge base
create_kb() {
    local name=$1
    local payload=$2
    
    log_info "Creating knowledge base: $name"
    
    HTTP_CODE=$(curl -s -o /tmp/kb_response.json -w "%{http_code}" \
        -X PUT "${SEARCH_ENDPOINT}/knowledgebases/${name}?api-version=${API_VERSION}" \
        -H "api-key: ${SEARCH_KEY}" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        log_success "Created knowledge base: $name"
    else
        log_warn "KB $name may already exist or error (HTTP $HTTP_CODE)"
        if [ "$VERBOSE" = true ]; then
            cat /tmp/kb_response.json
        fi
    fi
}

# Get OpenAI endpoint if not set
if [ -z "$OPENAI_ENDPOINT" ]; then
    log_warn "OPENAI_ENDPOINT not set, will use placeholder"
    OPENAI_ENDPOINT="https://your-openai.openai.azure.com"
fi

# 1. HR Knowledge Base - kb1-hr (matches portal-created name)
log_info "Creating kb1-hr with multiple sources..."
create_kb "kb1-hr" "{
    \"name\": \"kb1-hr\",
    \"description\": \"HR knowledge base for Zava\",
    \"retrievalInstructions\": \"Search for HR policies, employee benefits, PTO allowances, promotion guidelines, and compensation information.\",
    \"answerInstructions\": \"Provide clear, accurate answers about HR policies. Always cite the specific policy or document. If information is unclear, recommend contacting HR directly.\",
    \"outputMode\": \"answerSynthesis\",
    \"knowledgeSources\": [
        {\"name\": \"ks-hr-sharepoint\"},
        {\"name\": \"ks-hr-aisearch\"},
        {\"name\": \"ks-hr-web\"}
    ],
    \"models\": [{
        \"kind\": \"azureOpenAI\",
        \"azureOpenAIParameters\": {
            \"resourceUri\": \"${OPENAI_ENDPOINT}\",
            \"deploymentId\": \"gpt-4.1\",
            \"modelName\": \"gpt-4.1\"
        }
    }],
    \"retrievalReasoningEffort\": {\"kind\": \"medium\"}
}"

# 2. Marketing Knowledge Base - kb2-marketing (matches portal-created name)
log_info "Creating kb2-marketing..."
create_kb "kb2-marketing" "{
    \"name\": \"kb2-marketing\",
    \"description\": \"Marketing knowledge base for Zava\",
    \"retrievalInstructions\": \"Search for marketing campaigns, brand guidelines, social media strategies, content calendars, and campaign performance data.\",
    \"answerInstructions\": \"Provide actionable marketing insights. Reference specific campaigns, metrics, and guidelines. Suggest creative ideas when appropriate.\",
    \"outputMode\": \"answerSynthesis\",
    \"knowledgeSources\": [
        {\"name\": \"ks-marketing\"},
        {\"name\": \"ks-blob-marketing\"},
        {\"name\": \"ks-marketing-web\"}
    ],
    \"models\": [{
        \"kind\": \"azureOpenAI\",
        \"azureOpenAIParameters\": {
            \"resourceUri\": \"${OPENAI_ENDPOINT}\",
            \"deploymentId\": \"gpt-4.1\",
            \"modelName\": \"gpt-4.1\"
        }
    }],
    \"retrievalReasoningEffort\": {\"kind\": \"medium\"}
}"

# 3. Products Knowledge Base - kb3-products (matches portal-created name)
log_info "Creating kb3-products..."
create_kb "kb3-products" "{
    \"name\": \"kb3-products\",
    \"description\": \"Zava product catalog\",
    \"retrievalInstructions\": \"Search for product specifications, pricing, inventory levels, and product comparisons.\",
    \"answerInstructions\": \"Provide accurate product information including prices, features, and availability. Include SKU numbers when available.\",
    \"outputMode\": \"answerSynthesis\",
    \"knowledgeSources\": [
        {\"name\": \"ks-products\"},
        {\"name\": \"ks-products-onelake\"}
    ],
    \"models\": [{
        \"kind\": \"azureOpenAI\",
        \"azureOpenAIParameters\": {
            \"resourceUri\": \"${OPENAI_ENDPOINT}\",
            \"deploymentId\": \"gpt-4.1\",
            \"modelName\": \"gpt-4.1\"
        }
    }],
    \"retrievalReasoningEffort\": {\"kind\": \"medium\"}
}"

log_success "Knowledge bases created"
echo ""
log_info "Summary of Knowledge Bases:"
echo "  ✅ kb1-hr: [ks-hr-sharepoint, ks-hr-aisearch, ks-hr-web]"
echo "  ✅ kb2-marketing: [ks-marketing, ks-blob-marketing, ks-marketing-web]"
echo "  ✅ kb3-products: [ks-products, ks-products-onelake]"
echo ""
log_info "Note: Some knowledge sources require manual portal creation:"
echo "  - ks-blob-marketing (Azure Blob with UAMI)"
echo "  - ks-products-onelake (Fabric/OneLake)"
