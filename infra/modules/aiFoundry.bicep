@description('Name of the Azure OpenAI account')
param openAiName string

@description('Name of the Azure AI Hub workspace (Microsoft Foundry)')
param aiHubName string

@description('Location for all resources (westus3 supports GPT-4 and Phi)')
param location string

@description('Tags to apply to the resources')
param tags object = {}

// ---------------------------------------------------------------------------
// Storage account required by the AI Hub
// ---------------------------------------------------------------------------
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: take(toLower('st${replace(aiHubName, '-', '')}'), 24)
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// ---------------------------------------------------------------------------
// Key Vault required by the AI Hub
// ---------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: take('kv${replace(aiHubName, '-', '')}', 24)
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Azure OpenAI account — provides GPT-4 access in westus3
// ---------------------------------------------------------------------------
resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openAiName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: openAiName
  }
}

// GPT-4 model deployment
resource gpt4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAi
  name: 'gpt-4'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4'
      version: '0613'
    }
  }
}

// ---------------------------------------------------------------------------
// Azure AI Hub workspace — the Microsoft Foundry portal entry point.
// The model catalog (including Phi) is accessible from the Hub.
// ---------------------------------------------------------------------------
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: aiHubName
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: aiHubName
    storageAccount: storage.id
    keyVault: keyVault.id
    publicNetworkAccess: 'Enabled'
  }
}

// Connect the Azure OpenAI account to the AI Hub so GPT-4 (and Phi via model
// catalog) are accessible from within the Foundry portal.
resource openAiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01' = {
  parent: aiHub
  name: 'openai-connection'
  properties: {
    category: 'AzureOpenAI'
    authType: 'AAD'
    target: openAi.properties.endpoint
    metadata: {
      ApiType: 'Azure'
      ResourceId: openAi.id
    }
  }
}

output openAiEndpoint string = openAi.properties.endpoint
output openAiName string = openAi.name
output aiHubName string = aiHub.name
output aiHubId string = aiHub.id
