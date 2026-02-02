#!/bin/bash
#
# Setup Search Indexes
# Creates Azure AI Search indexes with semantic configuration
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh" 2>/dev/null || true

log_step "Creating Search Indexes"

API_VERSION="2024-07-01"

# Create index with semantic config
create_index() {
    local name=$1
    local description=$2
    
    log_info "Creating index: $name"
    
    HTTP_CODE=$(curl -s -o /tmp/index_response.json -w "%{http_code}" \
        -X PUT "${SEARCH_ENDPOINT}/indexes/${name}?api-version=${API_VERSION}" \
        -H "api-key: ${SEARCH_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "'"${name}"'",
            "fields": [
                {"name": "id", "type": "Edm.String", "key": true, "filterable": true},
                {"name": "content", "type": "Edm.String", "searchable": true, "analyzer": "standard.lucene"},
                {"name": "title", "type": "Edm.String", "searchable": true, "filterable": true, "sortable": true},
                {"name": "category", "type": "Edm.String", "searchable": true, "filterable": true, "facetable": true},
                {"name": "lastModified", "type": "Edm.DateTimeOffset", "filterable": true, "sortable": true},
                {"name": "url", "type": "Edm.String", "filterable": true}
            ],
            "semantic": {
                "defaultConfiguration": "default",
                "configurations": [{
                    "name": "default",
                    "prioritizedFields": {
                        "titleField": {"fieldName": "title"},
                        "prioritizedContentFields": [{"fieldName": "content"}],
                        "prioritizedKeywordsFields": [{"fieldName": "category"}]
                    }
                }]
            }
        }')
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        log_success "Created index: $name"
    else
        log_warn "Index $name may already exist or error occurred (HTTP $HTTP_CODE)"
        if [ "$VERBOSE" = true ]; then
            cat /tmp/index_response.json
        fi
    fi
}

# Create all indexes
create_index "index-hr" "HR policies, benefits, and employee information"
create_index "index-products" "Product catalog with specifications and pricing"
create_index "index-marketing" "Marketing campaigns, content, and analytics"
create_index "index-hr-sharepoint" "HR documents from SharePoint"

log_success "All indexes created"
