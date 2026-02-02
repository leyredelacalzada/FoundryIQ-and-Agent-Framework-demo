targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

@description('Location for the OpenAI resource')
@allowed(['australiaeast', 'brazilsouth', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'germanywestcentral', 'japaneast', 'koreacentral', 'northcentralus', 'norwayeast', 'polandcentral', 'southafricanorth', 'southcentralus', 'southindia', 'swedencentral', 'switzerlandnorth', 'uksouth', 'westeurope', 'westus', 'westus3'])
@metadata({
  azd: {
    type: 'location'
  }
})
param openAiLocation string

@description('Name of the chat GPT model deployment')
param chatGptModelName string = 'gpt-4o'

@description('Version of the chat GPT model')
param chatGptModelVersion string = '2024-08-06'

@description('Capacity of the chat GPT deployment')
param chatGptDeploymentCapacity int = 30

@description('Name of the embedding model deployment')
param embeddingModelName string = 'text-embedding-3-large'

@description('Version of the embedding model')
param embeddingModelVersion string = ''

@description('Capacity of the embedding model deployment')
param embeddingDeploymentCapacity int = 30

@description('Use Azure AI Foundry for agent framework')
param useAIFoundry bool = true

@description('Enable Entra ID authentication')
param useAuthentication bool = false

@description('Tenant ID for authentication')
param authTenantId string = ''

@description('ID of the principal to grant access')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Azure OpenAI
module openAi 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: rg
  params: {
    name: '${abbrs.cog}${resourceToken}'
    location: openAiLocation
    tags: tags
    sku: {
      name: 'S0'
    }
    kind: 'OpenAI'
    deployments: [
      {
        name: chatGptModelName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: chatGptModelVersion
        }
        sku: {
          name: 'GlobalStandard'
          capacity: chatGptDeploymentCapacity
        }
      }
      {
        name: embeddingModelName
        model: {
          format: 'OpenAI'
          name: embeddingModelName
          version: embeddingModelVersion
        }
        sku: {
          name: 'Standard'
          capacity: embeddingDeploymentCapacity
        }
      }
    ]
  }
}

// Azure AI Search
module searchService 'core/search/search-services.bicep' = {
  name: 'search-service'
  scope: rg
  params: {
    name: '${abbrs.srch}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'standard'  // Required for FoundryIQ agentic retrieval
    }
    semanticSearch: 'standard'  // Required for FoundryIQ Knowledge Bases
    // Enable RBAC authentication (Both: API keys + RBAC)
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

// Storage Account
module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: '${abbrs.st}${resourceToken}'
    location: location
    tags: tags
    containers: [
      { name: 'documents' }
      { name: 'agents' }
    ]
  }
}

// Container Apps Environment
module containerAppsEnvironment 'core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: '${abbrs.cae}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container Registry
module containerRegistry 'core/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    name: '${abbrs.cr}${resourceToken}'
    location: location
    tags: tags
  }
}

// Backend API
module backend 'core/host/container-app.bicep' = {
  name: 'backend'
  scope: rg
  params: {
    name: '${abbrs.ca}backend-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'backend' })
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    identityType: 'SystemAssigned'
    env: [
      { name: 'AZURE_OPENAI_ENDPOINT', value: openAi.outputs.endpoint }
      { name: 'AZURE_OPENAI_CHAT_DEPLOYMENT', value: chatGptModelName }
      { name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT', value: embeddingModelName }
      { name: 'AZURE_SEARCH_SERVICE', value: searchService.outputs.name }
      { name: 'AZURE_STORAGE_ACCOUNT', value: storage.outputs.name }
      { name: 'USE_AI_FOUNDRY', value: string(useAIFoundry) }
      { name: 'USE_AUTHENTICATION', value: string(useAuthentication) }
      { name: 'AUTH_TENANT_ID', value: authTenantId }
    ]
    targetPort: 8000
  }
}

// Role Assignments - User Principal
module openAiRoleUser 'core/security/role.bicep' = if (!empty(principalId)) {
  scope: rg
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
    principalType: 'User'
  }
}

module cognitiveServicesUserRole 'core/security/role.bicep' = if (!empty(principalId)) {
  scope: rg
  name: 'cognitive-services-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
    principalType: 'User'
  }
}

module aiDeveloperRoleUser 'core/security/role.bicep' = if (!empty(principalId)) {
  scope: rg
  name: 'ai-developer-user'
  params: {
    principalId: principalId
    roleDefinitionId: '64702f94-c441-49e6-a78b-ef80e0188fee' // Azure AI Developer
    principalType: 'User'
  }
}

module searchReaderRoleUser 'core/security/role.bicep' = if (!empty(principalId)) {
  scope: rg
  name: 'search-reader-user'
  params: {
    principalId: principalId
    roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f' // Search Index Data Reader
    principalType: 'User'
  }
}

module searchContributorRoleUser 'core/security/role.bicep' = if (!empty(principalId)) {
  scope: rg
  name: 'search-contributor-user'
  params: {
    principalId: principalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7' // Search Index Data Contributor
    principalType: 'User'
  }
}

module searchServiceContributorUser 'core/security/role.bicep' = if (!empty(principalId)) {
  scope: rg
  name: 'search-service-contributor-user'
  params: {
    principalId: principalId
    roleDefinitionId: '7ca78c08-252a-4471-8644-bb5ff32d4ba0' // Search Service Contributor
    principalType: 'User'
  }
}

module storageRoleUser 'core/security/role.bicep' = if (!empty(principalId)) {
  scope: rg
  name: 'storage-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    principalType: 'User'
  }
}

// Role Assignments - Backend Service Principal
module openAiRoleBackend 'core/security/role.bicep' = {
  scope: rg
  name: 'openai-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
    principalType: 'ServicePrincipal'
  }
}

module aiDeveloperRoleBackend 'core/security/role.bicep' = {
  scope: rg
  name: 'ai-developer-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '64702f94-c441-49e6-a78b-ef80e0188fee' // Azure AI Developer
    principalType: 'ServicePrincipal'
  }
}

module searchRoleBackend 'core/security/role.bicep' = {
  scope: rg
  name: 'search-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f' // Search Index Data Reader
    principalType: 'ServicePrincipal'
  }
}

module searchContributorRoleBackend 'core/security/role.bicep' = {
  scope: rg
  name: 'search-contributor-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7' // Search Index Data Contributor
    principalType: 'ServicePrincipal'
  }
}

module storageRoleBackend 'core/security/role.bicep' = {
  scope: rg
  name: 'storage-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    principalType: 'ServicePrincipal'
  }
}

// Role Assignments - Search Service Managed Identity (for KB model access)
module openAiRoleSearch 'core/security/role.bicep' = {
  scope: rg
  name: 'openai-role-search'
  params: {
    principalId: searchService.outputs.systemAssignedPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
    principalType: 'ServicePrincipal'
  }
}

module storageRoleSearch 'core/security/role.bicep' = {
  scope: rg
  name: 'storage-role-search'
  params: {
    principalId: searchService.outputs.systemAssignedPrincipalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    principalType: 'ServicePrincipal'
  }
}

// Outputs for azd
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_OPENAI_ENDPOINT string = openAi.outputs.endpoint
output AZURE_OPENAI_CHAT_DEPLOYMENT string = chatGptModelName
output AZURE_OPENAI_EMBEDDING_DEPLOYMENT string = embeddingModelName
output AZURE_SEARCH_SERVICE string = searchService.outputs.name
output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output BACKEND_URI string = backend.outputs.uri
