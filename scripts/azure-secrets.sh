#!/bin/bash

# Create Kubernetes secrets for Azure deployment
# Usage: ./scripts/azure-secrets.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE="cloudsound"

echo -e "${GREEN}Creating Kubernetes secrets for CloudSound${NC}\n"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured${NC}"
    echo "Run: az aks get-credentials --resource-group cloudsound-rg --name cloudsound-aks"
    exit 1
fi

# Check if Terraform outputs exist
if [ ! -f "infrastructure/terraform/terraform.tfstate" ]; then
    echo -e "${RED}Error: Terraform state not found${NC}"
    echo "Please run 'terraform apply' first"
    exit 1
fi

cd infrastructure/terraform

# Get outputs from Terraform
echo -e "${YELLOW}Reading Terraform outputs...${NC}"
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
ACR_NAME=$(terraform output -raw acr_name)
ACR_USERNAME=$(terraform output -raw acr_admin_username)
ACR_PASSWORD=$(terraform output -raw acr_admin_password)

DB_HOST=$(terraform output -raw postgres_server_fqdn)
DB_PASSWORD=$(terraform output -raw postgres_password)

STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
STORAGE_KEY=$(terraform output -raw storage_account_key)

APP_INSIGHTS_KEY=$(terraform output -raw app_insights_instrumentation_key)

cd ../..

# Create namespace
echo -e "\n${YELLOW}Creating namespace...${NC}"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create ACR image pull secret
echo -e "${YELLOW}Creating ACR image pull secret...${NC}"
kubectl create secret docker-registry acr-secret \
    --namespace $NAMESPACE \
    --docker-server=$ACR_LOGIN_SERVER \
    --docker-username=$ACR_USERNAME \
    --docker-password=$ACR_PASSWORD \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ ACR secret created${NC}"

# Create PostgreSQL secret
echo -e "${YELLOW}Creating PostgreSQL secret...${NC}"
kubectl create secret generic postgres-secret \
    --namespace $NAMESPACE \
    --from-literal=host=$DB_HOST \
    --from-literal=port=5432 \
    --from-literal=database=cloudsound \
    --from-literal=user=cloudsoundadmin \
    --from-literal=password=$DB_PASSWORD \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ PostgreSQL secret created${NC}"

# Create application secrets
echo -e "${YELLOW}Creating application secrets...${NC}"
kubectl create secret generic cloudsound-secrets \
    --namespace $NAMESPACE \
    --from-literal=secret-key="$(openssl rand -base64 32)" \
    --from-literal=jwt-secret="$(openssl rand -base64 32)" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Application secrets created${NC}"

# Create storage secret
echo -e "${YELLOW}Creating storage secret...${NC}"
kubectl create secret generic storage-secret \
    --namespace $NAMESPACE \
    --from-literal=account-name=$STORAGE_ACCOUNT \
    --from-literal=account-key=$STORAGE_KEY \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Storage secret created${NC}"

# Create Application Insights secret
echo -e "${YELLOW}Creating Application Insights secret...${NC}"
kubectl create secret generic app-insights-secret \
    --namespace $NAMESPACE \
    --from-literal=instrumentation-key=$APP_INSIGHTS_KEY \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Application Insights secret created${NC}"

# Verify secrets
echo -e "\n${YELLOW}Verifying secrets...${NC}"
kubectl get secrets -n $NAMESPACE

echo -e "\n${GREEN}All secrets created successfully! ✓${NC}"

