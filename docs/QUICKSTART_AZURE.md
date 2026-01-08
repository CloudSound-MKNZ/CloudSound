# CloudSound Azure Quick Start Guide

Get CloudSound running on Azure in under 30 minutes!

## Prerequisites

Before starting, install:
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Docker](https://docs.docker.com/get-docker/)

## Step 1: Azure Login (2 minutes)

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_NAME"

# Verify
az account show
```

## Step 2: Run Setup Script (5 minutes)

```bash
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound

# Run interactive setup
./scripts/azure-setup.sh
```

This will:
- ✅ Create resource group
- ✅ Register Azure providers
- ✅ Generate Terraform variables
- ✅ Create service principal for CI/CD

## Step 3: Deploy Infrastructure (10 minutes)

```bash
cd infrastructure/terraform

# Edit terraform.tfvars with your email
nano terraform.tfvars

# Deploy
terraform init
terraform apply
```

## Step 4: Configure Kubernetes (2 minutes)

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group cloudsound-rg \
  --name cloudsound-aks

# Verify
kubectl get nodes
```

## Step 5: Setup Ingress & SSL (5 minutes)

```bash
# Install nginx-ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Get ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Configure DNS: api.yourdomain.com -> $INGRESS_IP"
```

## Step 6: Create Secrets (2 minutes)

```bash
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound
./scripts/azure-secrets.sh
```

## Step 7: Build & Push Images (10 minutes)

```bash
# Get ACR info
cd infrastructure/terraform
ACR_NAME=$(terraform output -raw acr_name)
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
cd ../..

# Login to ACR
az acr login --name $ACR_NAME

# Build and push
export REGISTRY=$ACR_LOGIN_SERVER
./scripts/build-and-push-azure.sh
```

## Step 8: Deploy Application (5 minutes)

```bash
cd infrastructure/helm/cloudsound

# Update dependencies
helm dependency update

# Deploy
helm install cloudsound . \
  --namespace cloudsound \
  --create-namespace \
  --set global.imageRegistry=$ACR_LOGIN_SERVER \
  --set ingress.hosts[0].host=api.yourdomain.com \
  --values values-azure.yaml \
  --wait
```

## Step 9: Run Migrations (1 minute)

```bash
# Create migration job
kubectl apply -f infrastructure/kubernetes/migration-job.yaml

# Check status
kubectl get jobs -n cloudsound
```

## Step 10: Verify Deployment (2 minutes)

```bash
# Check pods
kubectl get pods -n cloudsound

# Check ingress
kubectl get ingress -n cloudsound

# Test API
curl https://api.yourdomain.com/health
```

## 🎉 Success!

Your CloudSound platform is now running on Azure!

## Next Steps

1. **Access Grafana**: https://monitoring.yourdomain.com
2. **View logs**: `kubectl logs -f deployment/api-gateway -n cloudsound`
3. **Scale services**: `kubectl scale deployment api-gateway --replicas=3 -n cloudsound`
4. **Setup CI/CD**: Add secrets to GitHub (see [AZURE_DEPLOYMENT.md](./AZURE_DEPLOYMENT.md))

## Automated Deployment

Want to do everything in one command?

```bash
./scripts/azure-deploy-all.sh
```

This script walks you through all steps interactively!

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod <pod-name> -n cloudsound
kubectl logs <pod-name> -n cloudsound
```

### Database connection issues

```bash
kubectl get secret postgres-secret -n cloudsound -o yaml
```

### Image pull errors

```bash
# Check ACR secret
kubectl get secret acr-secret -n cloudsound

# Re-create if needed
./scripts/azure-secrets.sh
```

## Cost Estimate

With Azure student credits ($100):
- **AKS**: ~$30-40/month
- **PostgreSQL**: ~$15-20/month
- **Storage**: ~$5/month
- **Total**: ~$50-65/month

Stop AKS when not in use:
```bash
az aks stop --resource-group cloudsound-rg --name cloudsound-aks
az aks start --resource-group cloudsound-rg --name cloudsound-aks
```

## Resources

- **Full Guide**: [AZURE_DEPLOYMENT.md](./AZURE_DEPLOYMENT.md)
- **Monitoring**: [AZURE_MONITORING.md](./AZURE_MONITORING.md)
- **Functions**: [AZURE_FUNCTIONS.md](./AZURE_FUNCTIONS.md)
- **Project Docs**: [README.md](../README.md)

## Support

For issues:
1. Check [AZURE_DEPLOYMENT.md](./AZURE_DEPLOYMENT.md) troubleshooting section
2. View Azure Portal for resource status
3. Check pod logs: `kubectl logs <pod-name> -n cloudsound`

---

**Happy deploying! 🚀**

