# GitHub Secrets Setup for CI/CD

This guide helps you configure GitHub repository secrets for Azure CI/CD pipelines.

## Option B (Multi-Repo) Deployment

We use **Option B**: each microservice is built and pushed from its **own repo**. The main **CloudSound** repo needs the full set of secrets below. Each **microservice repo** (e.g. `cloudsound-radio-streaming`, `cloudsound-api-gateway`) only needs the **ACR secrets** so it can push its image:

- **ACR_LOGIN_SERVER**
- **ACR_USERNAME**
- **ACR_PASSWORD**

See [docs/MULTIREPO_DEPLOY.md](../docs/MULTIREPO_DEPLOY.md) for the full workflow.

### Organization-Level Secrets (recommended for Option B)

Instead of adding ACR secrets to every microservice repo, use **organization-level secrets** so all `cloudsound-*` repos can access them.

1. **Go to your GitHub organization** (e.g. `CloudSound-MKNZ`).
2. **Settings** → **Secrets and variables** → **Actions**.
3. Click **Secrets** (or **New organization secret**).
4. **New organization secret**:
   - **Name**: e.g. `ACR_LOGIN_SERVER`
   - **Value**: your ACR URL (e.g. `yourregistry.azurecr.io`)
   - **Repository access**: choose **Selected repositories**, then add:
     - `cloudsound-api-gateway`
     - `cloudsound-authentication`
     - `cloudsound-radio-streaming`
     - `cloudsound-concert-management`
     - `cloudsound-analytics`
     - `cloudsound-music-discovery`
     - `cloudsound-event-manager`
     - `cloudsound-admin-management`
     - (and **CloudSound** if you want the main repo to use org secrets for ACR too)
5. Repeat for **ACR_USERNAME** and **ACR_PASSWORD** with the same repository access.

Workflows in those repos will see the secrets as `secrets.ACR_LOGIN_SERVER` etc. with no extra config. No need to add the same secrets to each repo.

**Note**: You must have **organization owner** (or “manage Actions” permission) to create org secrets. On GitHub Free, org secrets are only available to **public** repos; for private repos you need GitHub Team/Enterprise or add repo-level secrets.

---

## Required Secrets (CloudSound Repo)

You need to configure these secrets in the **CloudSound** repository for CI/CD to work:

### 1. Azure Credentials

#### AZURE_CREDENTIALS

Service principal credentials for GitHub Actions to access Azure.

**How to get it:**

```bash
# Login to Azure
az login

# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal
az ad sp create-for-rbac \
  --name "github-actions-cloudsound" \
  --role contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/cloudsound-rg" \
  --sdk-auth

# Copy the entire JSON output
```

**Value format:**
```json
{
  "clientId": "xxx",
  "clientSecret": "xxx",
  "subscriptionId": "xxx",
  "tenantId": "xxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

### 2. Azure Container Registry (ACR)

After running `terraform apply`, get these values:

```bash
cd infrastructure/terraform

# Get ACR login server
terraform output -raw acr_login_server

# Get ACR username
terraform output -raw acr_admin_username

# Get ACR password (sensitive)
terraform output -raw acr_admin_password
```

#### ACR_LOGIN_SERVER
- **Name**: `ACR_LOGIN_SERVER`
- **Value**: e.g., `cloudsoundacr123456.azurecr.io`

#### ACR_USERNAME
- **Name**: `ACR_USERNAME`
- **Value**: ACR admin username

#### ACR_PASSWORD
- **Name**: `ACR_PASSWORD`
- **Value**: ACR admin password (keep secret!)

### 3. Azure Kubernetes Service

#### AKS_RESOURCE_GROUP
- **Name**: `AKS_RESOURCE_GROUP`
- **Value**: `cloudsound-rg`

#### AKS_CLUSTER_NAME
- **Name**: `AKS_CLUSTER_NAME`
- **Value**: `cloudsound-aks`

### 4. Database

```bash
cd infrastructure/terraform

# Get PostgreSQL host
terraform output -raw postgres_server_fqdn
```

#### POSTGRES_HOST
- **Name**: `POSTGRES_HOST`
- **Value**: e.g., `cloudsound-postgres-xyz.postgres.database.azure.com`

#### POSTGRES_ADMIN_PASSWORD
- **Name**: `POSTGRES_ADMIN_PASSWORD`
- **Value**: PostgreSQL admin password (set in terraform.tfvars)

### 5. Domain Name

#### DOMAIN_NAME
- **Name**: `DOMAIN_NAME`
- **Value**: Your domain, e.g., `api.cloudsound.example.com`

---

## How to Add Secrets to GitHub

### Method 1: GitHub Web Interface

1. Go to your repository on GitHub
2. Click **Settings** (repository settings, not account settings)
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Enter the **Name** and **Value**
6. Click **Add secret**
7. Repeat for all secrets

### Method 2: GitHub CLI

Install GitHub CLI: https://cli.github.com/

```bash
# Login to GitHub
gh auth login

# Add secrets (example)
gh secret set AZURE_CREDENTIALS < azure-credentials.json
gh secret set ACR_LOGIN_SERVER --body "cloudsoundacr123456.azurecr.io"
gh secret set ACR_USERNAME --body "cloudsoundacr123456"
gh secret set ACR_PASSWORD --body "your-acr-password"
gh secret set AKS_RESOURCE_GROUP --body "cloudsound-rg"
gh secret set AKS_CLUSTER_NAME --body "cloudsound-aks"
gh secret set POSTGRES_HOST --body "cloudsound-postgres-xyz.postgres.database.azure.com"
gh secret set POSTGRES_ADMIN_PASSWORD --body "your-db-password"
gh secret set DOMAIN_NAME --body "api.cloudsound.example.com"
```

---

## Automated Script

Use this script to get all values and save them:

```bash
#!/bin/bash
# save-github-secrets.sh

cd infrastructure/terraform

echo "Getting values from Terraform..."

echo "=== Copy these values to GitHub Secrets ==="
echo ""
echo "ACR_LOGIN_SERVER:"
terraform output -raw acr_login_server
echo ""

echo "ACR_USERNAME:"
terraform output -raw acr_admin_username
echo ""

echo "ACR_PASSWORD:"
terraform output -raw acr_admin_password
echo ""

echo "POSTGRES_HOST:"
terraform output -raw postgres_server_fqdn
echo ""

echo "AKS_RESOURCE_GROUP: cloudsound-rg"
echo "AKS_CLUSTER_NAME: cloudsound-aks"
echo ""

echo "=== Service Principal JSON (AZURE_CREDENTIALS) ==="
echo "Run this command and copy the entire JSON output:"
echo ""
echo "az ad sp create-for-rbac --name 'github-actions-cloudsound' --role contributor --scopes /subscriptions/\$(az account show --query id -o tsv)/resourceGroups/cloudsound-rg --sdk-auth"
```

Make it executable and run:

```bash
chmod +x save-github-secrets.sh
./save-github-secrets.sh
```

---

## Verification

After adding all secrets, verify they're configured:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. You should see all 8 secrets listed:
   - ✅ AZURE_CREDENTIALS
   - ✅ ACR_LOGIN_SERVER
   - ✅ ACR_USERNAME
   - ✅ ACR_PASSWORD
   - ✅ AKS_RESOURCE_GROUP
   - ✅ AKS_CLUSTER_NAME
   - ✅ POSTGRES_HOST
   - ✅ POSTGRES_ADMIN_PASSWORD
   - ✅ DOMAIN_NAME

---

## Testing CI/CD

After configuring secrets, test the pipeline:

1. **Push to main branch**:
   ```bash
   git add .
   git commit -m "Setup Azure deployment"
   git push origin main
   ```

2. **Check GitHub Actions**:
   - Go to **Actions** tab in your repository
   - You should see workflows running

3. **Manual trigger** (if needed):
   - Go to **Actions** → Select workflow
   - Click **Run workflow**

---

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Rotate credentials** regularly
3. **Use minimal permissions** for service principal
4. **Enable 2FA** on GitHub account
5. **Review access logs** in Azure Portal
6. **Delete unused service principals**
7. **Use branch protection** rules

---

## Troubleshooting

### Issue: "Azure login failed"

Check AZURE_CREDENTIALS format:
- Must be valid JSON
- All fields present
- No extra whitespace

### Issue: "ACR login failed"

Check:
- ACR admin user is enabled
- Password is correct
- No special characters causing issues

### Issue: "kubectl not authorized"

Service principal needs AKS access:

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SP_ID=$(az ad sp list --display-name "github-actions-cloudsound" --query "[0].appId" -o tsv)

az role assignment create \
  --assignee $SP_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/cloudsound-rg/providers/Microsoft.ContainerService/managedClusters/cloudsound-aks"
```

### Issue: "Secret not found"

Ensure:
- Secret name matches exactly (case-sensitive)
- Secret is in correct repository
- You have admin access to repository

---

## Updating Secrets

To update a secret:

**Web Interface:**
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click on the secret name
3. Click **Update secret**
4. Enter new value
5. Click **Update secret**

**GitHub CLI:**
```bash
gh secret set SECRET_NAME --body "new-value"
```

---

## Environment-Specific Secrets

For multiple environments (staging, production):

1. Use **GitHub Environments**:
   - Settings → Environments → New environment
   - Add environment-specific secrets

2. Reference in workflow:
   ```yaml
   jobs:
     deploy:
       environment: production
       steps:
         - uses: azure/login@v1
           with:
             creds: ${{ secrets.AZURE_CREDENTIALS }}
   ```

---

## Additional Resources

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Azure Service Principals](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli)
- [GitHub CLI](https://cli.github.com/)

---

**Need help?** Check [AZURE_DEPLOYMENT.md](../docs/AZURE_DEPLOYMENT.md) for more details.

