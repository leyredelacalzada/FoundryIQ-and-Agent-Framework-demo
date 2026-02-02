#!/bin/bash
#
# Setup Fabric/OneLake Resources
# Creates Fabric capacity, workspace, lakehouse, and uploads product data
#
# NOTE: This script creates billable resources (F2 capacity ~$262/month)
#       Capacity can be paused to stop billing when not in use
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

log_step "Setting up Fabric/OneLake Resources"

# Configuration
CAPACITY_NAME="fabric${AZURE_ENV_NAME:-fiq}$(echo $RANDOM | md5sum | head -c 4)"
WORKSPACE_NAME="fiq-products-ws"
LAKEHOUSE_NAME="ProductsLakehouse"

# Get admin email
ADMIN_EMAIL=$(az account show --query user.name -o tsv)

log_info "Configuration:"
echo "  Capacity: $CAPACITY_NAME (F2 SKU)"
echo "  Workspace: $WORKSPACE_NAME"
echo "  Lakehouse: $LAKEHOUSE_NAME"
echo "  Admin: $ADMIN_EMAIL"
echo ""

# Check if Fabric capacity already exists
EXISTING_CAPACITY=$(az resource list -g "$RG_NAME" --resource-type "Microsoft.Fabric/capacities" --query "[0].name" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_CAPACITY" ]; then
    log_info "Using existing Fabric capacity: $EXISTING_CAPACITY"
    CAPACITY_NAME="$EXISTING_CAPACITY"
else
    log_info "Creating Fabric F2 capacity..."
    log_warn "This creates a billable resource (~\$262/month). Pause when not in use."
    
    az rest --method PUT \
        --url "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Fabric/capacities/${CAPACITY_NAME}?api-version=2023-11-01" \
        --body "{
            \"location\": \"${AZURE_LOCATION:-eastus}\",
            \"sku\": {\"name\": \"F2\", \"tier\": \"Fabric\"},
            \"properties\": {
                \"administration\": {
                    \"members\": [\"${ADMIN_EMAIL}\"]
                }
            }
        }" || {
            log_error "Failed to create Fabric capacity. You may need to create it manually."
            exit 1
        }
    
    log_info "Waiting for capacity to be Active..."
    for i in {1..30}; do
        STATE=$(az rest --method GET \
            --url "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Fabric/capacities/${CAPACITY_NAME}?api-version=2023-11-01" \
            2>/dev/null | jq -r '.properties.state' 2>/dev/null || echo "Unknown")
        
        if [ "$STATE" = "Active" ]; then
            log_success "Capacity is Active"
            break
        fi
        echo -n "."
        sleep 10
    done
fi

# Get Fabric API token
log_info "Getting Fabric API token..."
FABRIC_TOKEN=$(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)

# Get capacity GUID from Fabric API
log_info "Getting capacity GUID..."
CAPACITY_GUID=$(curl -s "https://api.fabric.microsoft.com/v1/capacities" \
    -H "Authorization: Bearer $FABRIC_TOKEN" | jq -r ".value[] | select(.displayName==\"$CAPACITY_NAME\") | .id")

if [ -z "$CAPACITY_GUID" ]; then
    log_error "Could not get capacity GUID. Capacity may not be licensed for Fabric."
    log_info "Please create workspace and lakehouse manually in Fabric portal."
    exit 1
fi

log_info "Capacity GUID: $CAPACITY_GUID"

# Create workspace
log_info "Creating Fabric workspace..."
WORKSPACE_RESULT=$(curl -s -X POST "https://api.fabric.microsoft.com/v1/workspaces" \
    -H "Authorization: Bearer $FABRIC_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"displayName\": \"$WORKSPACE_NAME\",
        \"capacityId\": \"$CAPACITY_GUID\",
        \"description\": \"Product data for FoundryIQ demo\"
    }")

WORKSPACE_ID=$(echo "$WORKSPACE_RESULT" | jq -r '.id')

if [ -z "$WORKSPACE_ID" ] || [ "$WORKSPACE_ID" = "null" ]; then
    # Try to get existing workspace
    WORKSPACE_ID=$(curl -s "https://api.fabric.microsoft.com/v1/workspaces" \
        -H "Authorization: Bearer $FABRIC_TOKEN" | jq -r ".value[] | select(.displayName==\"$WORKSPACE_NAME\") | .id")
    
    if [ -n "$WORKSPACE_ID" ]; then
        log_info "Using existing workspace: $WORKSPACE_ID"
    else
        log_error "Failed to create workspace"
        echo "$WORKSPACE_RESULT"
        exit 1
    fi
else
    log_success "Created workspace: $WORKSPACE_ID"
fi

export FABRIC_WORKSPACE_ID="$WORKSPACE_ID"

# Create lakehouse
log_info "Creating Lakehouse..."
LAKEHOUSE_RESULT=$(curl -s -X POST "https://api.fabric.microsoft.com/v1/workspaces/$WORKSPACE_ID/lakehouses" \
    -H "Authorization: Bearer $FABRIC_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"displayName\": \"$LAKEHOUSE_NAME\",
        \"description\": \"Product catalog data for Zava\"
    }")

LAKEHOUSE_ID=$(echo "$LAKEHOUSE_RESULT" | jq -r '.id')

if [ -z "$LAKEHOUSE_ID" ] || [ "$LAKEHOUSE_ID" = "null" ]; then
    # Try to get existing lakehouse
    LAKEHOUSE_ID=$(curl -s "https://api.fabric.microsoft.com/v1/workspaces/$WORKSPACE_ID/lakehouses" \
        -H "Authorization: Bearer $FABRIC_TOKEN" | jq -r ".value[] | select(.displayName==\"$LAKEHOUSE_NAME\") | .id")
    
    if [ -n "$LAKEHOUSE_ID" ]; then
        log_info "Using existing lakehouse: $LAKEHOUSE_ID"
    else
        log_error "Failed to create lakehouse"
        echo "$LAKEHOUSE_RESULT"
        exit 1
    fi
else
    log_success "Created lakehouse: $LAKEHOUSE_ID"
fi

export LAKEHOUSE_ID="$LAKEHOUSE_ID"

# Upload product data to OneLake
log_info "Uploading product data to OneLake..."

ONELAKE_TOKEN=$(az account get-access-token --resource https://storage.azure.com --query accessToken -o tsv)

# Create product catalog data
cat > /tmp/product_catalog.csv << 'PRODEOF'
product_id,name,category,price,stock,rating,description
ELEC-001,ZavaPhone Pro 15,Electronics,999.99,5000,4.8,Flagship smartphone with 6.7 inch OLED display and 5G
ELEC-002,ZavaBook Air M3,Electronics,1299.99,3000,4.9,Ultra-thin laptop with M3 chip and 18hr battery life
ELEC-003,ZavaPods Ultra,Electronics,249.99,15000,4.7,Wireless earbuds with active noise cancellation
HOME-001,ZavaSmart Hub,Smart Home,199.99,8000,4.6,Central home automation controller with voice control
HOME-002,ZavaRobo Vacuum X5,Smart Home,599.99,4000,4.5,AI-powered robot vacuum with mapping and mopping
FASH-001,ZavaWear Jacket,Fashion,149.99,2000,4.4,Water-resistant smart jacket with heating elements
FASH-002,ZavaFit Band Pro,Fashion,99.99,10000,4.6,Fitness band with health monitoring and GPS
SPORT-001,ZavaBike E-500,Sports,1999.99,500,4.7,Electric bike with 100km range and smart features
SPORT-002,ZavaRun Shoes,Sports,179.99,7500,4.8,Smart running shoes with gait analysis sensors
GROC-001,ZavaFresh Box,Grocery,29.99,25000,4.3,Weekly organic produce subscription box delivery
PRODEOF

# Create directory structure
curl -s -X PUT "https://onelake.dfs.fabric.microsoft.com/${WORKSPACE_ID}/${LAKEHOUSE_ID}/Files/products?resource=directory" \
    -H "Authorization: Bearer $ONELAKE_TOKEN" \
    -H "Content-Length: 0" || true

# Create file
curl -s -X PUT "https://onelake.dfs.fabric.microsoft.com/${WORKSPACE_ID}/${LAKEHOUSE_ID}/Files/products/product_catalog.csv?resource=file" \
    -H "Authorization: Bearer $ONELAKE_TOKEN" \
    -H "Content-Length: 0" || true

# Upload content
curl -s -X PATCH "https://onelake.dfs.fabric.microsoft.com/${WORKSPACE_ID}/${LAKEHOUSE_ID}/Files/products/product_catalog.csv?action=append&position=0" \
    -H "Authorization: Bearer $ONELAKE_TOKEN" \
    -H "Content-Type: text/csv" \
    --data-binary @/tmp/product_catalog.csv || true

# Flush
FILE_SIZE=$(wc -c < /tmp/product_catalog.csv | tr -d ' ')
curl -s -X PATCH "https://onelake.dfs.fabric.microsoft.com/${WORKSPACE_ID}/${LAKEHOUSE_ID}/Files/products/product_catalog.csv?action=flush&position=${FILE_SIZE}" \
    -H "Authorization: Bearer $ONELAKE_TOKEN" \
    -H "Content-Length: 0" || true

log_success "Product data uploaded to OneLake"

# Grant UAMI access to workspace (Viewer role)
if [ -n "$UAMI_PRINCIPAL_ID" ]; then
    log_info "Granting UAMI Viewer access to workspace..."
    curl -s -X POST "https://api.fabric.microsoft.com/v1/workspaces/$WORKSPACE_ID/roleAssignments" \
        -H "Authorization: Bearer $FABRIC_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"principal\": {
                \"id\": \"$UAMI_PRINCIPAL_ID\",
                \"type\": \"ServicePrincipal\"
            },
            \"role\": \"Viewer\"
        }" || log_warn "Could not assign workspace role (may already exist)"
fi

# Save IDs for later use
echo "FABRIC_WORKSPACE_ID=$WORKSPACE_ID" >> /tmp/fabric_env.sh
echo "LAKEHOUSE_ID=$LAKEHOUSE_ID" >> /tmp/fabric_env.sh
echo "CAPACITY_NAME=$CAPACITY_NAME" >> /tmp/fabric_env.sh

log_success "Fabric/OneLake setup complete"
echo ""
log_info "Resource IDs:"
echo "  Workspace ID: $WORKSPACE_ID"
echo "  Lakehouse ID: $LAKEHOUSE_ID"
echo "  Capacity: $CAPACITY_NAME"
echo ""
log_warn "MANUAL STEP REQUIRED:"
echo "  Add UAMI to OneLake security in Fabric portal"
echo "  See docs/MANUAL_STEPS.md for instructions"
echo ""
log_info "To pause capacity (stop billing):"
echo "  az rest --method POST --url \"https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Fabric/capacities/${CAPACITY_NAME}/suspend?api-version=2023-11-01\""
