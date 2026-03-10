targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g., dev)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'westus3'

@description('SKU for the Azure Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param acrSku string = 'Basic'

@description('SKU for the App Service Plan')
param appServicePlanSku string = 'B1'

// A short, deterministic token used to make resource names globally unique
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

var tags = {
  'azd-env-name': environmentName
  environment: environmentName
}

// Resource Group — all resources land in a single group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-zavastore-${environmentName}-${location}'
  location: location
  tags: tags
}

// Log Analytics workspace (backing store for Application Insights)
module logAnalytics './modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  scope: rg
  params: {
    name: 'law-${resourceToken}'
    location: location
    tags: tags
  }
}

// Application Insights for monitoring
module appInsights './modules/appInsights.bicep' = {
  name: 'appInsights'
  scope: rg
  params: {
    name: 'appi-${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Azure Container Registry — admin user disabled; App Service pulls via RBAC
module acr './modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    name: 'acr${resourceToken}'
    location: location
    tags: tags
    sku: acrSku
  }
}

// Linux App Service Plan + Web App for Containers with managed identity + AcrPull
module appService './modules/appService.bicep' = {
  name: 'appService'
  scope: rg
  params: {
    planName: 'asp-${resourceToken}'
    webAppName: 'app-zavastore-${resourceToken}'
    location: location
    tags: tags
    sku: appServicePlanSku
    acrLoginServer: acr.outputs.loginServer
    acrName: acr.outputs.name
    appInsightsConnectionString: appInsights.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
  }
}

// Microsoft AI Foundry — Azure OpenAI (GPT-4) + AI Hub (model catalog for Phi) in westus3
module aiFoundry './modules/aiFoundry.bicep' = {
  name: 'aiFoundry'
  scope: rg
  params: {
    openAiName: 'oai-${resourceToken}'
    aiHubName: 'aih-${resourceToken}'
    location: location
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Outputs consumed by AZD and CI/CD pipelines
// ---------------------------------------------------------------------------
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.name

output SERVICE_WEB_NAME string = appService.outputs.webAppName
output SERVICE_WEB_URI string = 'https://${appService.outputs.webAppDefaultHostname}'

output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsights.outputs.connectionString

output AZURE_OPENAI_ENDPOINT string = aiFoundry.outputs.openAiEndpoint
output AZURE_AI_HUB_NAME string = aiFoundry.outputs.aiHubName
