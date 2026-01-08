#!/bin/bash

# Complete deployment script for CloudSound on Azure
# This script automates the entire deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CloudSound Complete Azure Deployment${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

MISSING=0

if ! command -v az &> /dev/null; then
    echo -e "${RED}✗ Azure CLI not installed${NC}"
    MISSING=1
else
    echo -e "${GREEN}✓ Azure CLI installed${NC}"
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not installed${NC}"
    MISSING=1
else
    echo -e "${GREEN}✓ kubectl installed${NC}"
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ Helm not installed${NC}"
    MISSING=1
else
    echo -e "${GREEN}✓ Helm installed${NC}"
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform not installed${NC}"
    MISSING=1
else
    echo -e "${GREEN}✓ Terraform installed${NC}"
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not installed${NC}"
    MISSING=1
else
    echo -e "${GREEN}✓ Docker installed${NC}"
fi

if [ $MISSING -eq 1 ]; then
    echo -e "\n${RED}Missing required tools. Please install them first.${NC}"
    exit 1
fi

# Step 2: Azure login
echo -e "\n${YELLOW}Step 2: Checking Azure login...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Please log in to Azure:${NC}"
    az login
fi

az account show --output table

# Step 3: Deploy infrastructure with Terraform
echo -e "\n${YELLOW}Step 3: Deploying infrastructure with Terraform...${NC}"
read -p "Deploy infrastructure? This will cost Azure credits. (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd infrastructure/terraform
    
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "${YELLOW}No terraform.tfvars found. Creating from example...${NC}"
        cp terraform.tfvars.example terraform.tfvars
        echo -e "${RED}Please edit infrastructure/terraform/terraform.tfvars and run this script again${NC}"
        exit 1
    fi
    
    terraform init
    terraform validate
    terraform plan
    
    read -p "Apply Terraform plan? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply
        echo -e "${GREEN}✓ Infrastructure deployed${NC}"
    else
        echo -e "${YELLOW}Skipping Terraform apply${NC}"
        exit 0
    fi
    
    cd ../..
else
    echo -e "${YELLOW}Skipping infrastructure deployment${NC}"
fi

# Step 4: Configure kubectl
echo -e "\n${YELLOW}Step 4: Configuring kubectl...${NC}"
az aks get-credentials \
    --resource-group cloudsound-rg \
    --name cloudsound-aks \
    --overwrite-all

kubectl cluster-info
echo -e "${GREEN}✓ kubectl configured${NC}"

# Step 5: Install Ingress Controller
echo -e "\n${YELLOW}Step 5: Installing Ingress Controller...${NC}"
read -p "Install nginx-ingress? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --wait
    
    echo -e "${GREEN}✓ Ingress Controller installed${NC}"
    
    echo -e "\n${YELLOW}Waiting for external IP...${NC}"
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    
    INGRESS_IP=$(kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo -e "${GREEN}Ingress IP: $INGRESS_IP${NC}"
    echo -e "${YELLOW}Configure your DNS to point to this IP${NC}"
fi

# Step 6: Install cert-manager
echo -e "\n${YELLOW}Step 6: Installing cert-manager...${NC}"
read -p "Install cert-manager for SSL? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --wait
    
    echo -e "${GREEN}✓ cert-manager installed${NC}"
fi

# Step 7: Create Kubernetes secrets
echo -e "\n${YELLOW}Step 7: Creating Kubernetes secrets...${NC}"
./scripts/azure-secrets.sh

# Step 8: Build and push Docker images
echo -e "\n${YELLOW}Step 8: Building and pushing Docker images...${NC}"
read -p "Build and push images to ACR? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd infrastructure/terraform
    ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
    ACR_NAME=$(terraform output -raw acr_name)
    cd ../..
    
    az acr login --name $ACR_NAME
    
    export REGISTRY=$ACR_LOGIN_SERVER
    ./scripts/build-and-push-azure.sh
    
    echo -e "${GREEN}✓ Images built and pushed${NC}"
fi

# Step 9: Deploy application with Helm
echo -e "\n${YELLOW}Step 9: Deploying CloudSound application...${NC}"
read -p "Deploy CloudSound with Helm? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd infrastructure/helm/cloudsound
    
    helm dependency update
    
    read -p "Enter your domain name (e.g., api.cloudsound.example.com): " DOMAIN_NAME
    
    helm upgrade --install cloudsound . \
        --namespace cloudsound \
        --set global.imageRegistry=$ACR_LOGIN_SERVER \
        --set global.imagePullSecrets[0].name=acr-secret \
        --set postgresql.enabled=false \
        --set postgresql.external.enabled=true \
        --set ingress.enabled=true \
        --set ingress.className=nginx \
        --set ingress.hosts[0].host=$DOMAIN_NAME \
        --set ingress.tls[0].secretName=cloudsound-tls \
        --set ingress.tls[0].hosts[0]=$DOMAIN_NAME \
        --wait \
        --timeout 10m
    
    cd ../../..
    
    echo -e "${GREEN}✓ Application deployed${NC}"
fi

# Step 10: Run database migrations
echo -e "\n${YELLOW}Step 10: Running database migrations...${NC}"
read -p "Run database migrations? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration-$(date +%s)
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
  ttlSecondsAfterFinished: 300
EOF
    
    echo -e "${GREEN}✓ Migration job created${NC}"
    echo -e "${YELLOW}Check status: kubectl get jobs -n cloudsound${NC}"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}Deployment Complete! 🚀${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Check pod status: ${GREEN}kubectl get pods -n cloudsound${NC}"
echo -e "2. View services: ${GREEN}kubectl get svc -n cloudsound${NC}"
echo -e "3. Check ingress: ${GREEN}kubectl get ingress -n cloudsound${NC}"
echo -e "4. View logs: ${GREEN}kubectl logs -f deployment/api-gateway -n cloudsound${NC}"
echo -e "5. Access your application at: ${GREEN}https://$DOMAIN_NAME${NC}"

echo -e "\n${YELLOW}Useful commands:${NC}"
echo -e "- Port forward: ${GREEN}kubectl port-forward -n cloudsound svc/api-gateway 8000:80${NC}"
echo -e "- View all resources: ${GREEN}kubectl get all -n cloudsound${NC}"
echo -e "- Check certificates: ${GREEN}kubectl get certificate -n cloudsound${NC}"

echo -e "\n${GREEN}Happy deploying! 🎉${NC}\n"

