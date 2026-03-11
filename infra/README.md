# ZavaStorefront – Azure Infrastructure

## Architecture Overview

| Resource | Type | SKU | Purpose |
|---|---|---|---|
| Azure Container Registry | `Microsoft.ContainerRegistry/registries` | Basic | Store Docker images |
| App Service Plan | `Microsoft.Web/serverfarms` | B1 (Linux) | Host the Web App |
| Web App for Containers | `Microsoft.Web/sites` | — | Run the ZavaStorefront container |
| Application Insights | `Microsoft.Insights/components` | — | Application monitoring |
| Log Analytics Workspace | `Microsoft.OperationalInsights/workspaces` | PerGB2018 | Backend for App Insights |
| Azure AI Services | `Microsoft.CognitiveServices/accounts` | S0 | GPT-4 and Phi model access |
| Role Assignment | AcrPull | — | Web App → ACR passwordless pull |

All resources deploy into a single resource group (`rg-zavastore-dev-westus3`) in **westus3**.

## Prerequisites

- Azure CLI (`az`) installed
- Azure Developer CLI (`azd`) installed
- An Azure subscription with contributor access
- GitHub repository with OIDC federated credentials configured

## Deploy with AZD

```bash
# Login
azd auth login

# Provision infrastructure and deploy
azd up
```

AZD will:
1. Provision all Bicep-defined infrastructure
2. Build the Docker image using `az acr build` (no local Docker required)
3. Deploy the image to the Web App

## Deploy Manually

```bash
# Create resource group
az group create --name rg-zavastore-dev-westus3 --location westus3

# Deploy Bicep
az deployment group create \
  --resource-group rg-zavastore-dev-westus3 \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam

# Build and push image (cloud build, no local Docker)
az acr build --registry <ACR_NAME> \
  --image zavastore:latest \
  --file src/Dockerfile \
  src/
```

## GitHub Actions CI/CD

The workflow at `.github/workflows/build-deploy.yml` automates build and deploy on pushes to `main`.

### Required GitHub Secrets / Variables

| Name | Type | Description |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | Service principal / federated identity client ID |
| `AZURE_TENANT_ID` | Secret | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Azure subscription ID |
| `ACR_NAME` | Variable | ACR name (without .azurecr.io) |
| `AZURE_RESOURCE_GROUP` | Variable | Resource group name |
| `AZURE_WEBAPP_NAME` | Variable | Web App name |

## Infrastructure Files

```
infra/
├── main.bicep              # Main orchestration template
├── main.bicepparam         # Parameter file (dev defaults)
└── modules/
    ├── acr-pull-role.bicep       # AcrPull role assignment
    ├── ai-foundry.bicep          # AI Services + GPT-4/Phi deployments
    ├── app-insights.bicep        # App Insights + Log Analytics
    ├── app-service-plan.bicep    # Linux App Service Plan
    ├── container-registry.bicep  # Azure Container Registry
    └── web-app.bicep             # Web App for Containers
```

## Cost Notes (Dev Environment)

- **ACR Basic**: ~$5/month
- **App Service B1**: ~$13/month
- **AI Services S0**: Pay-per-use for model calls
- **Log Analytics**: Pay-per-GB ingested (first 5GB/month free)
- **Estimated total**: ~$20-30/month baseline + AI usage
