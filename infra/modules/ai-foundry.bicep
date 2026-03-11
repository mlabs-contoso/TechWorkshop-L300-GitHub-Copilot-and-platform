@description('Name of the Azure AI Services account')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply to the resource')
param tags object = {}

@description('SKU for the AI Services account')
param skuName string = 'S0'

// Azure AI Services (Cognitive Services) account for model deployments
resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: skuName
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: name
  }
}

// GPT-4o model deployment
resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: 'gpt-4o'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-08-06'
    }
  }
}

// Note: Phi-4 is available as a serverless model through Azure AI Foundry marketplace.
// It cannot be deployed as a standard Cognitive Services account deployment.
// After provisioning, deploy Phi-4 via the Azure AI Foundry portal or CLI:
//   az ml serverless-endpoint create --name phi4-endpoint --model-id azureml://registries/azureml/models/Phi-4

@description('The resource ID of the AI Services account')
output id string = aiServices.id

@description('The endpoint of the AI Services account')
output endpoint string = aiServices.properties.endpoint

@description('The name of the AI Services account')
output name string = aiServices.name
