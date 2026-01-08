# 🚀 CloudSound Azure Deployment Guide

Complete step-by-step guide for deploying CloudSound to Azure Cloud Platform.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure Setup](#azure-setup)
3. [Infrastructure Deployment (Terraform)](#infrastructure-deployment-terraform)
4. [Docker Images](#docker-images)
5. [Kubernetes Deployment](#kubernetes-deployment)
6. [Azure Functions](#azure-functions)
7. [CI/CD Setup](#cicd-setup)
8. [Monitoring & Observability](#monitoring--observability)
9. [Domain & SSL](#domain--ssl)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:

- ✅ **Azure Account** with $100 student credits ([Azure for Students](https://azure.microsoft.com/en-us/free/students/))
- ✅ **Azure CLI** installed ([Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- ✅ **kubectl** installed ([Install Guide](https://kubernetes.io/docs/tasks/tools/))
- ✅ **Helm 3.10+** installed ([Install Guide](https://helm.sh/docs/intro/install/))
- ✅ **Terraform 1.0+** installed ([Install Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli))
- ✅ **Docker** installed and running
- ✅ **Git** configured with your GitHub account

### Verify Installations

```bash
# Check Azure CLI
az --version

# Check kubectl
kubectl version --client

# Check Helm
helm version

# Check Terraform
terraform --version

# Check Docker
docker --version
```

---

## Azure Setup

### 1. Login to Azure

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"

# Verify current subscription
az account show
```

### 2. Create Resource Group

```bash
# Create a resource group for CloudSound
az group create \
  --name cloudsound-rg \
  --location eastus

# Verify
az group show --name cloudsound-rg
```

### 3. Register Required Resource Providers

```bash
# Register providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.DBforPostgreSQL

# Check registration status (wait until all show "Registered")
az provider show --namespace Microsoft.ContainerService --query "registrationState"
az provider show --namespace Microsoft.Storage --query "registrationState"
```

---

## Infrastructure Deployment (Terraform)

We'll use Terraform to create all Azure infrastructure automatically.

### 1. Navigate to Terraform Directory

```bash
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound/infrastructure/terraform
```

### 2. Configure Variables

Edit `terraform.tfvars`:

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Update with your values:

```hcl
# Azure Configuration
resource_group_name = "cloudsound-rg"
location            = "eastus"
project_name        = "cloudsound"
environment         = "production"

# AKS Configuration
aks_node_count      = 2
aks_node_size       = "Standard_B2s"  # Free tier eligible

# Database Configuration
postgres_sku_name   = "B_Gen5_1"      # Basic tier
postgres_storage_mb = 5120            # 5GB

# Your email for SSL certificates
admin_email         = "your-email@example.com"
```

### 3. Initialize Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview what will be created
terraform plan
```

### 4. Deploy Infrastructure

```bash
# Apply the configuration (creates all resources)
terraform apply

# Type 'yes' when prompted
```

This will create:
- ✅ Azure Kubernetes Service (AKS) cluster
- ✅ Azure Container Registry (ACR)
- ✅ Azure Database for PostgreSQL
- ✅ Azure Storage Account (for MinIO/blob storage)
- ✅ Virtual Network and Subnets
- ✅ Network Security Groups
- ✅ Public IP addresses

**Time to complete**: ~10-15 minutes

### 5. Save Terraform Outputs

```bash
# Get important values
terraform output

# Save AKS credentials
az aks get-credentials \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --overwrite-all

# Verify connection
kubectl cluster-info
kubectl get nodes
```

---

## Docker Images

### 1. Login to Azure Container Registry

```bash
# Get ACR login server
ACR_NAME=$(terraform output -raw acr_name)
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)

# Login to ACR
az acr login --name $ACR_NAME

# Or use Docker login
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
echo $ACR_PASSWORD | docker login $ACR_LOGIN_SERVER --username $ACR_NAME --password-stdin
```

### 2. Build and Push Images

```bash
# Navigate to project root
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound

# Set registry variable
export REGISTRY=$ACR_LOGIN_SERVER

# Build and push all images
./scripts/build-and-push-azure.sh
```

Or manually:

```bash
# API Gateway
docker build -f backend/api-gateway/Dockerfile -t $REGISTRY/api-gateway:latest .
docker push $REGISTRY/api-gateway:latest

# Authentication
docker build -f backend/authentication/Dockerfile -t $REGISTRY/authentication:latest .
docker push $REGISTRY/authentication:latest

# Radio Streaming
docker build -f backend/radio-streaming/Dockerfile -t $REGISTRY/radio-streaming:latest .
docker push $REGISTRY/radio-streaming:latest

# Concert Management
docker build -f backend/concert-management/Dockerfile -t $REGISTRY/concert-management:latest .
docker push $REGISTRY/concert-management:latest

# Analytics
docker build -f backend/analytics/Dockerfile -t $REGISTRY/analytics:latest .
docker push $REGISTRY/analytics:latest

# Music Discovery
docker build -f backend/music-discovery/Dockerfile -t $REGISTRY/music-discovery:latest .
docker push $REGISTRY/music-discovery:latest

# Event Manager
docker build -f backend/event-manager/Dockerfile -t $REGISTRY/event-manager:latest .
docker push $REGISTRY/event-manager:latest

# Frontend
docker build -f frontend/Dockerfile -t $REGISTRY/frontend:latest ./frontend
docker push $REGISTRY/frontend:latest

# Verify images
az acr repository list --name $ACR_NAME --output table
```

---

## Kubernetes Deployment

### 1. Configure kubectl for AKS

```bash
# Get AKS credentials (if not already done)
az aks get-credentials \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --overwrite-all

# Verify connection
kubectl get nodes
```

### 2. Create Namespace and Secrets

```bash
# Create namespace
kubectl create namespace cloudsound

# Create image pull secret (for ACR)
kubectl create secret docker-registry acr-secret \
  --namespace cloudsound \
  --docker-server=$ACR_LOGIN_SERVER \
  --docker-username=$ACR_NAME \
  --docker-password=$ACR_PASSWORD

# Create database secret
DB_HOST=$(terraform output -raw postgres_server_fqdn)
DB_PASSWORD=$(terraform output -raw postgres_password)

kubectl create secret generic postgres-secret \
  --namespace cloudsound \
  --from-literal=host=$DB_HOST \
  --from-literal=port=5432 \
  --from-literal=database=cloudsound \
  --from-literal=user=cloudsoundadmin \
  --from-literal=password=$DB_PASSWORD

# Create application secrets
kubectl create secret generic cloudsound-secrets \
  --namespace cloudsound \
  --from-literal=secret-key="$(openssl rand -base64 32)" \
  --from-literal=jwt-secret="$(openssl rand -base64 32)"

# Create storage account secret
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
STORAGE_KEY=$(terraform output -raw storage_account_key)

kubectl create secret generic storage-secret \
  --namespace cloudsound \
  --from-literal=account-name=$STORAGE_ACCOUNT \
  --from-literal=account-key=$STORAGE_KEY
```

### 3. Install Ingress Controller

```bash
# Add nginx-ingress Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install nginx-ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

# Wait for external IP
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Get external IP
kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

### 4. Deploy with Helm

```bash
# Navigate to Helm chart
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound/infrastructure/helm/cloudsound

# Update dependencies
helm dependency update

# Create values file for Azure
cat > values-azure.yaml <<EOF
global:
  environment: production
  imageRegistry: "$ACR_LOGIN_SERVER"
  imagePullSecrets:
    - name: acr-secret

postgresql:
  enabled: false  # Using Azure Database for PostgreSQL
  external:
    enabled: true
    host: $DB_HOST
    port: 5432
    database: cloudsound
    existingSecret: postgres-secret

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: api.cloudsound.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: cloudsound-tls
      hosts:
        - api.cloudsound.yourdomain.com

resources:
  api-gateway:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
EOF

# Install CloudSound
helm install cloudsound . \
  --namespace cloudsound \
  --values values-azure.yaml \
  --wait \
  --timeout 10m

# Check deployment
kubectl get pods -n cloudsound
kubectl get svc -n cloudsound
kubectl get ingress -n cloudsound
```

### 5. Run Database Migrations

```bash
# Create migration job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  namespace: cloudsound
spec:
  template:
    spec:
      containers:
      - name: migration
        image: $ACR_LOGIN_SERVER/api-gateway:latest
        command: ["sh", "-c"]
        args:
          - |
            cd /app/backend/shared/db
            alembic upgrade head
        env:
        - name: POSTGRES_HOST
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: host
        - name: POSTGRES_PORT
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: port
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: database
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: user
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
      restartPolicy: OnFailure
      imagePullSecrets:
      - name: acr-secret
  backoffLimit: 3
EOF

# Check migration status
kubectl get jobs -n cloudsound
kubectl logs -n cloudsound job/db-migration
```

---

## Azure Functions

Deploy the serverless metadata extraction function.

### 1. Install Azure Functions Core Tools

```bash
# Linux/WSL
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install azure-functions-core-tools-4
```

### 2. Create Function App

```bash
# Create storage account for function app
FUNCTION_STORAGE="cloudsoundfunc$(openssl rand -hex 4)"
az storage account create \
  --name $FUNCTION_STORAGE \
  --resource-group cloudsound-rg \
  --location eastus \
  --sku Standard_LRS

# Create Function App (Python 3.11)
az functionapp create \
  --resource-group cloudsound-rg \
  --name cloudsound-metadata-extractor \
  --storage-account $FUNCTION_STORAGE \
  --consumption-plan-location eastus \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --os-type Linux
```

### 3. Configure Function App

```bash
# Set application settings
az functionapp config appsettings set \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --settings \
    KAFKA_BOOTSTRAP_SERVERS="your-kafka-broker:9092" \
    STORAGE_CONNECTION_STRING="$STORAGE_KEY"
```

### 4. Deploy Function

```bash
# Navigate to functions directory
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound/azure-functions

# Deploy
func azure functionapp publish cloudsound-metadata-extractor

# Test function
func azure functionapp list-functions cloudsound-metadata-extractor
```

---

## CI/CD Setup

### 1. GitHub Actions Setup

#### a. Create GitHub Secrets

Go to your GitHub repository → Settings → Secrets → Actions, and add:

```
AZURE_CREDENTIALS         (from: az ad sp create-for-rbac)
ACR_LOGIN_SERVER          (your ACR URL)
ACR_USERNAME              (ACR admin username)
ACR_PASSWORD              (ACR admin password)
AKS_RESOURCE_GROUP        cloudsound-rg
AKS_CLUSTER_NAME          cloudsound-aks
```

Get Azure credentials:

```bash
# Create service principal for GitHub Actions
az ad sp create-for-rbac \
  --name "github-actions-cloudsound" \
  --role contributor \
  --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/cloudsound-rg \
  --sdk-auth

# Copy the entire JSON output to AZURE_CREDENTIALS secret
```

#### b. Workflows are Ready

GitHub Actions workflows are already created in `.github/workflows/`:
- `deploy-to-azure.yml` - Main deployment pipeline
- `build-images.yml` - Build and push Docker images
- `terraform.yml` - Infrastructure as code

### 2. Manual Trigger

```bash
# Push to main branch to trigger deployment
git add .
git commit -m "Deploy to Azure"
git push origin main
```

---

## Monitoring & Observability

### 1. Deploy Prometheus & Grafana

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi

# Install Grafana (included in kube-prometheus-stack)
# Get Grafana password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Access: http://localhost:3000 (admin / <password-from-above>)
```

### 2. Azure Monitor Integration

```bash
# Enable Azure Monitor for containers
az aks enable-addons \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --addons monitoring

# Create Log Analytics workspace (if not exists)
az monitor log-analytics workspace create \
  --resource-group cloudsound-rg \
  --workspace-name cloudsound-logs \
  --location eastus

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group cloudsound-rg \
  --workspace-name cloudsound-logs \
  --query id -o tsv)

# Link AKS to workspace
az aks enable-addons \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --addons monitoring \
  --workspace-resource-id $WORKSPACE_ID
```

### 3. Application Insights (Optional)

```bash
# Create Application Insights
az monitor app-insights component create \
  --app cloudsound-insights \
  --resource-group cloudsound-rg \
  --location eastus \
  --application-type web

# Get instrumentation key
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app cloudsound-insights \
  --resource-group cloudsound-rg \
  --query instrumentationKey -o tsv)

# Add to services as environment variable
kubectl set env deployment/api-gateway \
  -n cloudsound \
  APPINSIGHTS_INSTRUMENTATIONKEY=$INSTRUMENTATION_KEY
```

---

## Domain & SSL

### 1. Configure DNS

Get the Ingress external IP:

```bash
INGRESS_IP=$(kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

Add DNS A records (in your domain provider):
```
api.cloudsound.yourdomain.com    -> $INGRESS_IP
app.cloudsound.yourdomain.com    -> $INGRESS_IP
```

### 2. Install cert-manager

```bash
# Add cert-manager Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Wait for cert-manager to be ready
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s
```

### 3. Create ClusterIssuer for Let's Encrypt

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Verify
kubectl get clusterissuer
```

### 4. Update Ingress for TLS

The Helm chart already has TLS configured. Certificates will be automatically issued.

```bash
# Check certificate status
kubectl get certificate -n cloudsound
kubectl describe certificate -n cloudsound cloudsound-tls

# Check ingress
kubectl get ingress -n cloudsound
```

---

## Verification & Testing

### 1. Check All Services

```bash
# Check pods
kubectl get pods -n cloudsound

# Check services
kubectl get svc -n cloudsound

# Check ingress
kubectl get ingress -n cloudsound

# Check certificates
kubectl get certificate -n cloudsound
```

### 2. Test API Endpoints

```bash
# Get API URL
API_URL=$(kubectl get ingress -n cloudsound -o jsonpath='{.items[0].spec.rules[0].host}')

# Test health endpoint
curl https://$API_URL/health

# Test API Gateway
curl https://$API_URL/api/v1/health

# Test specific services
curl https://$API_URL/api/v1/radio/stations
curl https://$API_URL/api/v1/concerts
```

### 3. Access Frontend

```bash
# If using separate frontend domain
curl https://app.cloudsound.yourdomain.com
```

---

## Scaling

### 1. Manual Scaling

```bash
# Scale AKS nodes
az aks scale \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --node-count 3

# Scale application pods
kubectl scale deployment api-gateway -n cloudsound --replicas=3
kubectl scale deployment radio-streaming -n cloudsound --replicas=2
```

### 2. Enable Autoscaling

```bash
# Enable cluster autoscaler
az aks update \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 5

# Configure HPA (Horizontal Pod Autoscaler)
kubectl autoscale deployment api-gateway \
  -n cloudsound \
  --cpu-percent=70 \
  --min=2 \
  --max=10
```

---

## Cost Optimization

### 1. Use Spot Instances

```bash
# Add spot node pool
az aks nodepool add \
  --resource-group cloudsound-rg \
  --cluster-name cloudsound-aks \
  --name spotpool \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --node-count 1 \
  --node-vm-size Standard_B2s
```

### 2. Stop AKS Cluster (Development)

```bash
# Stop cluster to save costs
az aks stop \
  --resource-group cloudsound-rg \
  --name cloudsound-aks

# Start cluster
az aks start \
  --resource-group cloudsound-rg \
  --name cloudsound-aks
```

### 3. Monitor Costs

```bash
# View cost analysis
az consumption usage list --output table

# Set budget alerts in Azure Portal
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n cloudsound

# Describe pod
kubectl describe pod <pod-name> -n cloudsound

# Check logs
kubectl logs <pod-name> -n cloudsound
kubectl logs <pod-name> -n cloudsound --previous  # Previous crash

# Common issues:
# 1. Image pull errors - Check ACR authentication
# 2. Database connection - Check postgres-secret
# 3. Missing environment variables - Check secrets
```

### Database Connection Issues

```bash
# Test connection from pod
kubectl run -it --rm debug \
  --image=postgres:15-alpine \
  --restart=Never \
  -n cloudsound -- \
  psql -h $DB_HOST -U cloudsoundadmin -d cloudsound

# Check firewall rules
az postgres server firewall-rule list \
  --resource-group cloudsound-rg \
  --server-name cloudsound-postgres
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress -n cloudsound

# Check external IP
kubectl get svc -n ingress-nginx

# Check logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Certificate Issues

```bash
# Check certificate status
kubectl describe certificate -n cloudsound cloudsound-tls

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Delete and recreate certificate
kubectl delete certificate cloudsound-tls -n cloudsound
# Will be auto-recreated by cert-manager
```

---

## Cleanup

### Delete Everything (Careful!)

```bash
# Delete Kubernetes resources
helm uninstall cloudsound -n cloudsound
kubectl delete namespace cloudsound

# Delete Azure resources with Terraform
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound/infrastructure/terraform
terraform destroy

# Or delete resource group (deletes EVERYTHING)
az group delete --name cloudsound-rg --yes --no-wait
```

---

## Next Steps

After deployment:

1. ✅ **Configure monitoring** - Set up dashboards in Grafana
2. ✅ **Set up alerts** - Configure Azure Monitor alerts
3. ✅ **Enable backups** - Configure database backups
4. ✅ **Security hardening** - Enable Azure Security Center
5. ✅ **Load testing** - Test with realistic loads
6. ✅ **Documentation** - Update API documentation
7. ✅ **Team access** - Add team members to Azure Portal

---

## Useful Commands

```bash
# View all resources
az resource list --resource-group cloudsound-rg --output table

# Get AKS credentials
az aks get-credentials --resource-group cloudsound-rg --name cloudsound-aks

# Update kubectl context
kubectl config use-context cloudsound-aks

# Port-forward services for local testing
kubectl port-forward -n cloudsound svc/api-gateway 8000:80
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# View logs
kubectl logs -f deployment/api-gateway -n cloudsound

# Execute into pod
kubectl exec -it <pod-name> -n cloudsound -- /bin/bash
```

---

## Support & Resources

- **Azure Documentation**: https://docs.microsoft.com/azure
- **AKS Documentation**: https://docs.microsoft.com/azure/aks
- **Terraform Azure Provider**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **Helm Charts**: https://helm.sh/docs

---

**Happy Deploying! 🚀**

For questions or issues, check the troubleshooting section or create an issue in the repository.

