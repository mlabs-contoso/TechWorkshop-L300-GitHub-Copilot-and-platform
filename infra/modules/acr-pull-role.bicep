@description('Name of the role assignment (must be a GUID)')
param name string = guid(acrId, principalId, roleDefinitionId)

@description('Resource ID of the Azure Container Registry')
param acrId string

@description('Principal ID of the managed identity to grant access')
param principalId string

@description('The role definition ID for AcrPull')
param roleDefinitionId string = '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull built-in role

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: last(split(acrId, '/'))
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: name
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
