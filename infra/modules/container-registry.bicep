@description('Name of the Azure Container Registry')
param name string

@description('Location for the resource')
param location string

@description('SKU for the container registry')
@allowed(['Basic', 'Standard', 'Premium'])
param skuName string = 'Basic'

@description('Tags to apply to the resource')
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: false
  }
}

@description('The resource ID of the container registry')
output id string = acr.id

@description('The login server of the container registry')
output loginServer string = acr.properties.loginServer

@description('The name of the container registry')
output name string = acr.name
