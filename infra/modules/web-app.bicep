@description('Name of the Web App')
param name string

@description('Location for the resource')
param location string

@description('Resource ID of the App Service Plan')
param appServicePlanId string

@description('Login server of the Azure Container Registry')
param acrLoginServer string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Docker image and tag to deploy')
param dockerImageAndTag string = 'zavastore:latest'

@description('Tags to apply to the resource')
param tags object = {}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/${dockerImageAndTag}'
      acrUseManagedIdentityCreds: true
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrLoginServer}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
      ]
    }
    httpsOnly: true
  }
}

@description('The resource ID of the Web App')
output id string = webApp.id

@description('The default hostname of the Web App')
output defaultHostName string = webApp.properties.defaultHostName

@description('The principal ID of the system-assigned managed identity')
output principalId string = webApp.identity.principalId

@description('The name of the Web App')
output name string = webApp.name
