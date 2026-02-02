#!/bin/bash
#
# Common functions for deployment scripts
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_step() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
}

# Check required environment variables
check_env() {
    local var_name=$1
    if [ -z "${!var_name}" ]; then
        log_error "Required environment variable not set: $var_name"
        exit 1
    fi
}

# API call with retry
api_call() {
    local method=$1
    local url=$2
    local data=$3
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if [ -n "$data" ]; then
            HTTP_CODE=$(curl -s -o /tmp/api_response.json -w "%{http_code}" \
                -X "$method" "$url" \
                -H "api-key: ${SEARCH_KEY}" \
                -H "Content-Type: application/json" \
                -d "$data")
        else
            HTTP_CODE=$(curl -s -o /tmp/api_response.json -w "%{http_code}" \
                -X "$method" "$url" \
                -H "api-key: ${SEARCH_KEY}")
        fi
        
        if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
            return 0
        elif [ "$HTTP_CODE" -eq 429 ]; then
            retry=$((retry + 1))
            log_warn "Rate limited, waiting 10s... (attempt $retry/$max_retries)"
            sleep 10
        else
            return 1
        fi
    done
    return 1
}
