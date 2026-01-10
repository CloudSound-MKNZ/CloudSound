# CloudSound Terraform Infrastructure

This directory contains Terraform configuration for deploying CloudSound infrastructure to Azure.

## Prerequisites

1. **Azure CLI** installed and configured
2. **Terraform** 1.0+ installed
3. **Azure subscription** with sufficient credits

## Quick Start

### 1. Login to Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_NAME"
```

### 2. Configure Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan Deployment

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

## What Gets Created

This Terraform configuration creates:

### Networking
- Virtual Network (VNet)
- Subnets for AKS and PostgreSQL
- Network Security Groups
- Private DNS Zone for PostgreSQL

### Compute
- **Azure Kubernetes Service (AKS)** cluster
  - 2 nodes (default)
  - Standard_B2s VM size
  - System-assigned managed identity
  - Azure CNI networking

### Container Registry
- **Azure Container Registry (ACR)**
  - Basic SKU
  - Admin enabled for easy access
  - Integrated with AKS

### Database
- **PostgreSQL Flexible Server**
  - Version 15
  - Basic tier (B_Standard_B1ms)
  - 32GB storage
  - Private endpoint integration
  - Database created automatically

### Storage
- **Storage Account**
  - Standard LRS
  - Blob containers for audio and metadata
  - CORS configured

### Event Streaming
- **Azure Event Hubs Namespace**
  - Standard tier
  - Kafka protocol enabled
  - SASL authentication
- **Azure Event Hubs** (4 event hubs):
  - `concert-events` - Concert creation/update events
  - `music-events` - Music download and metadata events
  - `playback-events` - Playback tracking events
  - `raw-events` - Raw Facebook events

### Monitoring
- **Log Analytics Workspace**
  - 30-day retention
  - Connected to AKS

- **Application Insights**
  - Web application type
  - Linked to Log Analytics

## Resource Naming Convention

Resources follow this naming pattern:
- Resource Group: `cloudsound-rg`
- AKS Cluster: `cloudsound-aks`
- ACR: `cloudsoundacr<random>`
- PostgreSQL: `cloudsound-postgres-<random>`
- Event Hubs Namespace: `cloudsound-events-<random>`
- Storage: `cloudsoundstorage<random>`

The `<random>` suffix ensures globally unique names.

## Cost Optimization

### Estimated Monthly Costs (with Azure Student Credits)

| Resource | SKU | Estimated Cost |
|----------|-----|----------------|
| AKS (2 nodes) | Standard_B2s | ~$30-40/month |
| PostgreSQL | B_Standard_B1ms | ~$15-20/month |
| Azure Event Hubs | Standard tier, 1 TU | ~$10-20/month |
| ACR | Basic | ~$5/month |
| Storage | Standard LRS | ~$1-2/month |
| **Total** | | **~$60-90/month** |

### Cost-Saving Tips

1. **Stop AKS when not in use** (development):
   ```bash
   az aks stop --resource-group cloudsound-rg --name cloudsound-aks
   az aks start --resource-group cloudsound-rg --name cloudsound-aks
   ```

2. **Use smaller node sizes**: Change `aks_node_size` to `Standard_B1s` for minimal testing

3. **Reduce node count**: Set `aks_node_count = 1` for development

4. **Lower database tier**: Use `B_Standard_B1ms` (already configured)

5. **Set resource limits**: Configure appropriate resource requests/limits in Kubernetes

## Outputs

After deployment, Terraform outputs important information:

```bash
# View all outputs
terraform output

# View specific output
terraform output aks_cluster_name
terraform output acr_login_server
terraform output postgres_server_fqdn
terraform output eventhubs_bootstrap_servers
terraform output eventhubs_namespace_name

# View sensitive outputs
terraform output -raw postgres_password
terraform output -raw acr_admin_password
terraform output -raw eventhubs_connection_string
```

## Post-Deployment Steps

After `terraform apply` completes:

### 1. Configure kubectl

```bash
az aks get-credentials \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --overwrite-all

kubectl get nodes
```

### 2. Login to ACR

```bash
ACR_NAME=$(terraform output -raw acr_name)
az acr login --name $ACR_NAME
```

### 3. Build and Push Images

```bash
# Get ACR login server
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)

# Build and push images
export REGISTRY=$ACR_LOGIN_SERVER
../../../scripts/build-and-push-azure.sh
```

### 4. Deploy Application

```bash
# Deploy with Helm
cd ../helm/cloudsound
helm install cloudsound . \
  --namespace cloudsound \
  --create-namespace \
  --set global.imageRegistry=$ACR_LOGIN_SERVER \
  --values values-azure.yaml
```

## State Management

### Local State (Default)

By default, Terraform state is stored locally in `terraform.tfstate`.

**Important**: Never commit `terraform.tfstate` to Git (it's in `.gitignore`).

### Remote State (Recommended for Teams)

To use remote state in Azure Storage:

1. Create storage account for state:
   ```bash
   az group create --name terraform-state-rg --location eastus
   
   az storage account create \
     --resource-group terraform-state-rg \
     --name cloudsoundtfstate \
     --sku Standard_LRS \
     --encryption-services blob
   
   az storage container create \
     --name tfstate \
     --account-name cloudsoundtfstate
   ```

2. Uncomment the `backend` block in `main.tf`:
   ```hcl
   backend "azurerm" {
     resource_group_name  = "terraform-state-rg"
     storage_account_name = "cloudsoundtfstate"
     container_name       = "tfstate"
     key                  = "cloudsound.terraform.tfstate"
   }
   ```

3. Initialize backend:
   ```bash
   terraform init -migrate-state
   ```

## Updating Infrastructure

To update existing infrastructure:

```bash
# Make changes to .tf or .tfvars files

# Preview changes
terraform plan

# Apply changes
terraform apply

# Or auto-approve (use with caution)
terraform apply -auto-approve
```

## Destroying Infrastructure

To remove all created resources:

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Or auto-approve (use with caution)
terraform destroy -auto-approve
```

**Warning**: This will delete ALL resources including data!

## Troubleshooting

### Issue: "Error creating resource"

Check if you have sufficient Azure credits and permissions:
```bash
az account show
az account list-locations
```

### Issue: "Resource name already exists"

The random suffix should prevent this, but if it happens:
```bash
terraform destroy
terraform apply
```

### Issue: "Insufficient quota"

Request quota increase in Azure Portal or use smaller node sizes.

### Issue: "PostgreSQL connection failed"

Check firewall rules and private endpoint configuration:
```bash
az postgres flexible-server show \
  --resource-group cloudsound-rg \
  --name cloudsound-postgres-<random>
```

### Issue: "AKS nodes not ready"

Check node status:
```bash
kubectl get nodes
kubectl describe node <node-name>
```

## Variables Reference

See `variables.tf` for all available variables and their descriptions.

## Files

- `main.tf` - Main infrastructure configuration
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `terraform.tfvars` - Your configuration values (not in Git)
- `terraform.tfvars.example` - Example configuration
- `.terraform/` - Terraform cache (not in Git)
- `terraform.tfstate` - State file (not in Git)

## Security Notes

1. **Never commit sensitive files**:
   - `terraform.tfvars` (contains credentials)
   - `terraform.tfstate` (contains secrets)
   - `.terraform/` (cache)

2. **Use Azure Key Vault** for production secrets

3. **Enable RBAC** for AKS access control

4. **Use private endpoints** for databases (already configured)

5. **Rotate credentials** regularly

## Additional Resources

- [Azure Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Azure Database for PostgreSQL](https://docs.microsoft.com/azure/postgresql/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Azure Portal for resource status
3. Check Terraform logs: `TF_LOG=DEBUG terraform apply`
4. Consult Azure documentation

