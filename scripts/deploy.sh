#!/bin/bash
#
# FoundryIQ + Agent Framework Demo - Full Deployment Script
#
# This script deploys all Azure resources and configures FoundryIQ:
# 1. Azure infrastructure via azd (OpenAI, Search, Storage, Container Apps)
# 2. User-Assigned Managed Identity with permissions
# 3. Search indexes with sample Zava e-commerce data
# 4. Knowledge Sources (searchIndex, web, azureBlob, SharePoint indexed, OneLake)
# 5. Knowledge Bases (kb-hr, kb-marketing, kb-products)
# 6. Fabric/OneLake setup (optional)
#
# Usage:
#   ./scripts/deploy.sh                    # Full deployment
#   ./scripts/deploy.sh --skip-infra       # Skip azd infrastructure
#   ./scripts/deploy.sh --skip-fabric      # Skip Fabric/OneLake setup
#   ./scripts/deploy.sh --help             # Show help
#
# Prerequisites:
#   - Azure CLI logged in (az login)
#   - azd CLI installed
#   - jq installed
#
# Manual steps required after deployment:
#   1. Azure Blob KS: Create via portal with UAMI (shared key disabled)
#   2. OneLake Security: Add UAMI to DefaultReader role in Fabric portal
#   3. SharePoint (optional): Create site and app registration
#

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
SKIP_INFRA=false
SKIP_FABRIC=false
SKIP_ONELAKE_KS=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-infra)
            SKIP_INFRA=true
            shift
            ;;
        --skip-fabric)
            SKIP_FABRIC=true
            SKIP_ONELAKE_KS=true
            shift
            ;;
        --skip-onelake-ks)
            SKIP_ONELAKE_KS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-infra      Skip Azure infrastructure deployment (azd)"
            echo "  --skip-fabric     Skip Fabric capacity and OneLake setup"
            echo "  --skip-onelake-ks Skip OneLake knowledge source (requires manual portal setup)"
            echo "  --verbose         Show detailed output"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

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

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites"
    
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found. Install from https://aka.ms/installazurecli"
        exit 1
    fi
    
    if ! command -v azd &> /dev/null; then
        log_error "Azure Developer CLI not found. Install from https://aka.ms/install-azd"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install with: apt-get install jq"
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Run: az login"
        exit 1
    fi
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    log_info "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
    
    log_success "All prerequisites met"
}

# Deploy Azure infrastructure
deploy_infrastructure() {
    if [ "$SKIP_INFRA" = true ]; then
        log_warn "Skipping infrastructure deployment (--skip-infra)"
        return
    fi
    
    log_step "Deploying Azure infrastructure with azd"
    
    cd "$REPO_ROOT"
    
    # Check if environment exists
    if ! azd env list 2>/dev/null | grep -q .; then
        log_info "Creating new azd environment..."
        azd env new
    fi
    
    # Deploy infrastructure and app
    azd up
    
    log_success "Infrastructure deployed"
}

# Get deployment outputs and set environment variables
load_environment() {
    log_step "Loading environment configuration"
    
    cd "$REPO_ROOT"
    
    # Get values from azd environment
    export AZURE_ENV_NAME=$(azd env get-value AZURE_ENV_NAME 2>/dev/null || echo "")
    export AZURE_LOCATION=$(azd env get-value AZURE_LOCATION 2>/dev/null || echo "eastus")
    export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    
    # Derive resource names from environment
    if [ -n "$AZURE_ENV_NAME" ]; then
        export RG_NAME="rg-${AZURE_ENV_NAME}"
    else
        # Fallback: try to find resource group
        export RG_NAME=$(az group list --query "[?contains(name,'fiq')].name" -o tsv | head -1)
        if [ -z "$RG_NAME" ]; then
            log_error "Could not determine resource group. Run azd up first or set AZURE_ENV_NAME"
            exit 1
        fi
    fi
    
    log_info "Resource Group: $RG_NAME"
    
    # Get resource names from resource group
    export SEARCH_SERVICE=$(az search service list -g "$RG_NAME" --query "[0].name" -o tsv 2>/dev/null)
    export OPENAI_SERVICE=$(az cognitiveservices account list -g "$RG_NAME" --query "[?kind=='OpenAI'].name" -o tsv 2>/dev/null)
    export STORAGE_ACCOUNT=$(az storage account list -g "$RG_NAME" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$SEARCH_SERVICE" ]; then
        log_error "AI Search service not found in $RG_NAME"
        exit 1
    fi
    
    if [ -z "$OPENAI_SERVICE" ]; then
        log_error "OpenAI service not found in $RG_NAME"
        exit 1
    fi
    
    # Get endpoints
    export SEARCH_ENDPOINT="https://${SEARCH_SERVICE}.search.windows.net"
    export OPENAI_ENDPOINT=$(az cognitiveservices account show -n "$OPENAI_SERVICE" -g "$RG_NAME" --query "properties.endpoint" -o tsv)
    
    # Get admin key for Search
    export SEARCH_KEY=$(az search admin-key show -g "$RG_NAME" --service-name "$SEARCH_SERVICE" --query primaryKey -o tsv)
    
    log_info "Search Service: $SEARCH_SERVICE"
    log_info "OpenAI Service: $OPENAI_SERVICE"
    log_info "Storage Account: $STORAGE_ACCOUNT"
    
    log_success "Environment loaded"
}

# Create User-Assigned Managed Identity
create_uami() {
    log_step "Creating User-Assigned Managed Identity"
    
    UAMI_NAME="uami-${AZURE_ENV_NAME:-fiq-demo}"
    
    # Check if UAMI exists
    if az identity show -n "$UAMI_NAME" -g "$RG_NAME" &> /dev/null; then
        log_info "UAMI already exists: $UAMI_NAME"
    else
        log_info "Creating UAMI: $UAMI_NAME"
        az identity create -n "$UAMI_NAME" -g "$RG_NAME" -l "$AZURE_LOCATION"
    fi
    
    export UAMI_PRINCIPAL_ID=$(az identity show -n "$UAMI_NAME" -g "$RG_NAME" --query principalId -o tsv)
    export UAMI_RESOURCE_ID=$(az identity show -n "$UAMI_NAME" -g "$RG_NAME" --query id -o tsv)
    
    log_info "UAMI Principal ID: $UAMI_PRINCIPAL_ID"
    
    # Assign permissions
    log_info "Assigning UAMI permissions..."
    
    SEARCH_ID="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Search/searchServices/${SEARCH_SERVICE}"
    STORAGE_ID="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}"
    
    # Search Index Data Reader
    az role assignment create --assignee-object-id "$UAMI_PRINCIPAL_ID" \
        --role "1407120a-92aa-4202-b7e9-c0e197c71c8f" \
        --scope "$SEARCH_ID" \
        --assignee-principal-type ServicePrincipal 2>/dev/null || true
    
    # Search Index Data Contributor
    az role assignment create --assignee-object-id "$UAMI_PRINCIPAL_ID" \
        --role "8ebe5a00-799e-43f5-93ac-243d3dce84a7" \
        --scope "$SEARCH_ID" \
        --assignee-principal-type ServicePrincipal 2>/dev/null || true
    
    # Storage Blob Data Reader
    az role assignment create --assignee-object-id "$UAMI_PRINCIPAL_ID" \
        --role "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1" \
        --scope "$STORAGE_ID" \
        --assignee-principal-type ServicePrincipal 2>/dev/null || true
    
    log_success "UAMI created with permissions"
}

# Run sub-scripts
run_subscript() {
    local script_name=$1
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [ -f "$script_path" ]; then
        log_info "Running $script_name..."
        chmod +x "$script_path"
        bash "$script_path"
    else
        log_error "Script not found: $script_path"
        exit 1
    fi
}

# Main deployment flow
main() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  FoundryIQ + Agent Framework Demo Deployment                  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_prerequisites
    deploy_infrastructure
    load_environment
    create_uami
    
    # Export variables for sub-scripts
    export AZURE_SUBSCRIPTION_ID
    export RG_NAME
    export SEARCH_SERVICE
    export SEARCH_ENDPOINT
    export SEARCH_KEY
    export OPENAI_SERVICE
    export OPENAI_ENDPOINT
    export STORAGE_ACCOUNT
    export UAMI_PRINCIPAL_ID
    export UAMI_RESOURCE_ID
    export SKIP_FABRIC
    export SKIP_ONELAKE_KS
    
    # Run setup scripts
    run_subscript "setup_indexes.sh"
    run_subscript "upload_sample_data.sh"
    run_subscript "setup_knowledge_sources.sh"
    run_subscript "setup_knowledge_bases.sh"
    
    if [ "$SKIP_FABRIC" = false ]; then
        run_subscript "setup_fabric.sh"
    else
        log_warn "Skipping Fabric/OneLake setup (--skip-fabric)"
    fi
    
    # Print summary
    log_step "Deployment Complete!"
    
    echo ""
    echo -e "${GREEN}Resources Created:${NC}"
    echo "  • Resource Group: $RG_NAME"
    echo "  • AI Search: $SEARCH_SERVICE"
    echo "  • OpenAI: $OPENAI_SERVICE"
    echo "  • Storage: $STORAGE_ACCOUNT"
    echo "  • UAMI: uami-${AZURE_ENV_NAME:-fiq-demo}"
    echo ""
    echo -e "${GREEN}FoundryIQ Resources:${NC}"
    echo "  • Indexes: index-hr, index-products, index-marketing"
    echo "  • Knowledge Sources:"
    echo "    - ks-hr-sharepoint, ks-hr-aisearch, ks-hr-web (HR)"
    echo "    - ks-marketing, ks-blob-marketing*, ks-marketing-web (Marketing)"
    echo "    - ks-products, ks-products-onelake* (Products)"
    echo "  • Knowledge Bases: kb1-hr, kb2-marketing, kb3-products"
    echo ""
    echo -e "${YELLOW}Manual Steps Required:${NC}"
    echo "  1. Search RBAC: Portal → Search service → Keys → 'Both' (API keys + RBAC)"
    echo "  2. Blob KS*: Create ks-blob-marketing in Portal (UAMI auth required)"
    echo "  3. OneLake*: Add UAMI to DefaultReader role in Fabric portal"
    echo ""
    echo "See docs/MANUAL_STEPS.md for detailed instructions."
    echo ""
    
    log_success "Deployment completed successfully!"
}

# Run main
main "$@"
