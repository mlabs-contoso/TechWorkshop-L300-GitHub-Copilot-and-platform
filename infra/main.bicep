targetScope = 'resourceGroup'

@description('Environment name (e.g., dev, staging, prod)')
param environmentName string

@description('Primary location for all resources')
param location string

@description('Base name prefix for resources')
param resourceNamePrefix string = 'zavastore'

@description('SKU for App Service Plan')
param appServicePlanSku string = 'B1'

@description('SKU for Azure Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param acrSku string = 'Basic'

@description('Docker image and tag')
param dockerImageAndTag string = 'zavastore:latest'

// Generate unique suffix for globally unique resource names
var uniqueSuffix = uniqueString(resourceGroup().id)
var baseName = '${resourceNamePrefix}-${environmentName}'

var tags = {
  environment: environmentName
  project: 'ZavaStorefront'
}

// Azure Container Registry
module acr 'modules/container-registry.bicep' = {
  name: 'acr'
  params: {
    name: replace('acr${baseName}${uniqueSuffix}', '-', '')
    location: location
    skuName: acrSku
    tags: tags
  }
}

// Application Insights + Log Analytics
module monitoring 'modules/app-insights.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: 'log-${baseName}'
    appInsightsName: 'appi-${baseName}'
    location: location
    tags: tags
  }
}

// App Service Plan (Linux)
module appServicePlan 'modules/app-service-plan.bicep' = {
  name: 'appServicePlan'
  params: {
    name: 'plan-${baseName}'
    location: location
    skuName: appServicePlanSku
    tags: tags
  }
}

// Web App for Containers
module webApp 'modules/web-app.bicep' = {
  name: 'webApp'
  params: {
    name: 'app-${baseName}-${uniqueSuffix}'
    location: location
    appServicePlanId: appServicePlan.outputs.id
    acrLoginServer: acr.outputs.loginServer
    appInsightsConnectionString: monitoring.outputs.connectionString
    dockerImageAndTag: dockerImageAndTag
    tags: union(tags, { 'azd-service-name': 'web' })
  }
}

// AcrPull role assignment for Web App managed identity
module acrPullRole 'modules/acr-pull-role.bicep' = {
  name: 'acrPullRole'
  params: {
    acrId: acr.outputs.id
    principalId: webApp.outputs.principalId
  }
}

// Azure AI Foundry (AI Services + model deployments)
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'aiFoundry'
  params: {
    name: 'ai-${baseName}-${uniqueSuffix}'
    location: location
    tags: tags
  }
}

// Outputs
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.loginServer
output webAppUrl string = 'https://${webApp.outputs.defaultHostName}'
output appInsightsConnectionString string = monitoring.outputs.connectionString
output aiServicesEndpoint string = aiFoundry.outputs.endpoint
output resourceGroupName string = resourceGroup().name
output webAppName string = webApp.outputs.name
