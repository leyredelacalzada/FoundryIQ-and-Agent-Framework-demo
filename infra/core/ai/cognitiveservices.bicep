metadata description = 'Creates an Azure Cognitive Services account (OpenAI or AI Services).'

param name string
param location string = resourceGroup().location
param tags object = {}

@allowed(['OpenAI', 'AIServices'])
param kind string = 'OpenAI'

param sku object = {
  name: 'S0'
}

param deployments array = []

@description('Disable local API key authentication')
param disableLocalAuth bool = true

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: sku
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: disableLocalAuth
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deployment in deployments: {
  parent: cognitiveServices
  name: deployment.name
  sku: deployment.sku
  properties: {
    model: deployment.model
    raiPolicyName: deployment.?raiPolicyName ?? null
  }
}]

output id string = cognitiveServices.id
output name string = cognitiveServices.name
output endpoint string = cognitiveServices.properties.endpoint
output principalId string = cognitiveServices.identity.principalId
