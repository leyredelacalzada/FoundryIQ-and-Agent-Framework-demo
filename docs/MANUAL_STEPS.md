# Manual Configuration Steps

Some FoundryIQ features require manual portal configuration due to API limitations. This document covers all manual steps.

## Table of Contents
1. [Azure Blob Knowledge Source](#1-azure-blob-knowledge-source)
2. [OneLake Security Configuration](#2-onelake-security-configuration)
3. [Updating Knowledge Bases](#3-updating-knowledge-bases-after-manual-steps)
4. [SharePoint Indexer Setup](#4-sharepoint-indexer-setup-optional)

---

## 1. Azure Blob Knowledge Source

### Why Manual?
When shared key access is disabled on storage accounts (security best practice), Azure Blob knowledge sources must be created via the Azure Portal with User-Assigned Managed Identity authentication. The REST API doesn't fully support this flow.

### Prerequisites
- Storage account: `st{env}fiqmaf` (created by deployment)
- Container: `marketing-docs` with sample data uploaded
- UAMI with Storage Blob Data Reader role on the container

### Steps

1. **Navigate to Azure AI Search**
   - Go to [Azure Portal](https://portal.azure.com)
   - Open your search service (e.g., `srch-{env}-fiq-maf-demo`)

2. **Open Agentic Retrieval**
   - In the left menu, select **Agentic Retrieval (preview)**
   - Select **Knowledge Sources** tab

3. **Create Blob Knowledge Source**
   - Click **+ Create**
   - Select **Azure Blob Storage**
   - Configure:
     - **Name**: `ks-blob-marketing`
     - **Description**: `Marketing PDFs and documents from Blob storage`
     - **Storage Account**: Select your storage account
     - **Container**: `marketing-docs`
   
4. **Configure Authentication**
   - Under **Authentication**, select **User-assigned managed identity**
   - Select your UAMI: `uami-{env}-fiq-maf-demo`
   - Click **Create**

5. **Wait for Ingestion**
   - The KS will show "Indexing" status
   - Wait until status changes to "Ready" (~5-10 minutes)

---

## 2. OneLake Security Configuration

### Why Manual?
OneLake security (preview) requires adding the UAMI as a reader via the Fabric portal. There's no public API for this configuration.

### Prerequisites
- Fabric workspace created: `fiq-products-ws`
- Lakehouse created: `ProductsLakehouse`
- Product data uploaded to `/Files/products/`
- UAMI with Viewer role on the workspace

### Steps

1. **Open Microsoft Fabric Portal**
   - Go to [https://app.fabric.microsoft.com](https://app.fabric.microsoft.com)
   - Select your workspace: `fiq-products-ws`

2. **Navigate to Lakehouse**
   - Open the `ProductsLakehouse`
   - Verify data exists in `Files/products/`

3. **Open OneLake Security**
   - In the lakehouse view, click **...** (more options)
   - Select **OneLake security (preview)**

4. **Add UAMI to DefaultReader Role**
   - Find the **DefaultReader** role (or appropriate read role)
   - Click **Add members**
   - Search for your UAMI name: `uami-{env}-fiq-maf-demo`
   - Select the managed identity and **Save**

5. **Verify Access**
   - The UAMI should now appear in the role members list
   - This allows the search service to read OneLake data

### Creating OneLake Knowledge Source

After OneLake security is configured, create the knowledge source:

```bash
# Set variables
SEARCH_ENDPOINT="https://srch-{env}-fiq-maf-demo.search.windows.net"
SEARCH_KEY="<your-admin-key>"
FABRIC_WORKSPACE_ID="<from-fabric-portal>"
LAKEHOUSE_ID="<from-fabric-portal>"
UAMI_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uami-{env}-fiq-maf-demo"
OPENAI_ENDPOINT="https://oai-{env}-fiq-maf-demo.openai.azure.com"

# Create the knowledge source
curl -X PUT "${SEARCH_ENDPOINT}/knowledgesources/ks-products-onelake?api-version=2025-11-01-preview" \
  -H "api-key: ${SEARCH_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ks-products-onelake",
    "kind": "indexedOneLake",
    "description": "Product catalog from Fabric Lakehouse",
    "indexedOneLakeParameters": {
        "fabricWorkspaceId": "'${FABRIC_WORKSPACE_ID}'",
        "lakehouseId": "'${LAKEHOUSE_ID}'",
        "targetPath": "/Files/products"
    },
    "ingestionParameters": {
        "identity": {
            "@odata.type": "#Microsoft.Azure.Search.SearchIndexerDataUserAssignedIdentity",
            "userAssignedIdentity": "'${UAMI_RESOURCE_ID}'"
        },
        "disableImageVerbalization": true,
        "contentExtractionMode": "minimal",
        "embeddingModel": {
            "kind": "azureOpenAI",
            "azureOpenAIParameters": {
                "resourceUri": "'${OPENAI_ENDPOINT}'",
                "deploymentId": "text-embedding-3-large",
                "modelName": "text-embedding-3-large"
            }
        }
    }
}'
```

---

## 3. Updating Knowledge Bases After Manual Steps

After creating the Blob and OneLake knowledge sources, update the knowledge bases to include them:

### Add ks-blob-marketing to kb-marketing

```bash
# Get current KB and add the new KS
curl -X PATCH "${SEARCH_ENDPOINT}/knowledgebases/kb-marketing?api-version=2025-11-01-preview" \
  -H "api-key: ${SEARCH_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "knowledgeSources": [
        {"name": "ks-marketing"},
        {"name": "ks-marketing-web"},
        {"name": "ks-blob-marketing"}
    ]
}'
```

### Add ks-products-onelake to kb-products

```bash
curl -X PATCH "${SEARCH_ENDPOINT}/knowledgebases/kb-products?api-version=2025-11-01-preview" \
  -H "api-key: ${SEARCH_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "knowledgeSources": [
        {"name": "ks-products"},
        {"name": "ks-products-onelake"}
    ]
}'
```

---

## 4. SharePoint Indexer Setup (Optional)

### Overview
To index SharePoint documents, you need:
1. An Entra ID App Registration with SharePoint permissions
2. A SharePoint site with documents
3. An indexer configured in Azure AI Search

### App Registration

1. **Create App Registration**
   - Azure Portal → Entra ID → App Registrations → New
   - Name: `srch-{env}-sharepoint-indexer`
   - Redirect URI: Leave blank

2. **Add API Permissions**
   - Microsoft Graph:
     - `Files.Read.All` (Application)
     - `Sites.Read.All` (Application)
   - Grant admin consent

3. **Create Client Secret**
   - Certificates & secrets → New client secret
   - Save the secret value (you'll need it)

### Create SharePoint Data Source

```bash
curl -X PUT "${SEARCH_ENDPOINT}/datasources/ds-hr-sharepoint?api-version=2025-11-01-preview" \
  -H "api-key: ${SEARCH_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ds-hr-sharepoint",
    "type": "sharepoint",
    "credentials": {
        "connectionString": "SharePointOnlineEndpoint=https://{tenant}.sharepoint.com/sites/{site};ApplicationId={app-id};ApplicationSecret={secret};TenantId={tenant-id}"
    },
    "container": {
        "name": "useQuery",
        "query": "includeLibrariesInSite=true"
    }
}'
```

### Create SharePoint Indexer

```bash
curl -X PUT "${SEARCH_ENDPOINT}/indexers/indexer-hr-sharepoint?api-version=2025-11-01-preview" \
  -H "api-key: ${SEARCH_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "indexer-hr-sharepoint",
    "dataSourceName": "ds-hr-sharepoint",
    "targetIndexName": "index-hr-sharepoint",
    "parameters": {
        "configuration": {
            "indexedFileNameExtensions": ".pdf,.docx,.doc,.pptx,.xlsx"
        }
    },
    "schedule": {
        "interval": "PT4H"
    }
}'
```

---

## Quick Reference: Finding Resource IDs

### Get Fabric Workspace ID
```bash
# From Fabric portal URL: app.fabric.microsoft.com/groups/{WORKSPACE_ID}
# Or via API:
FABRIC_TOKEN=$(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)
curl -s "https://api.fabric.microsoft.com/v1/workspaces" \
  -H "Authorization: Bearer $FABRIC_TOKEN" | jq '.value[] | {name: .displayName, id: .id}'
```

### Get Lakehouse ID  
```bash
curl -s "https://api.fabric.microsoft.com/v1/workspaces/${WORKSPACE_ID}/lakehouses" \
  -H "Authorization: Bearer $FABRIC_TOKEN" | jq '.value[] | {name: .displayName, id: .id}'
```

### Get UAMI Resource ID
```bash
az identity show -g rg-{env}-fiq-maf-demo -n uami-{env}-fiq-maf-demo --query id -o tsv
```

### Get UAMI Principal ID (for Fabric role assignments)
```bash
az identity show -g rg-{env}-fiq-maf-demo -n uami-{env}-fiq-maf-demo --query principalId -o tsv
```

---

## Troubleshooting

### Blob KS "Forbidden" Error
- Verify UAMI has `Storage Blob Data Reader` role on the container
- Check if shared key access is disabled on storage account
- Ensure firewall allows search service access

### OneLake KS "Unauthorized" Error
- Verify UAMI is added to OneLake security
- Check UAMI has Viewer role on workspace
- Ensure identity format uses `SearchIndexerDataUserAssignedIdentity`

### Knowledge Base Query Returns Empty
- Wait for KS ingestion to complete (check status in portal)
- Verify KB includes the correct knowledge sources
- Test individual KS queries first
