#!/bin/bash

# Complete deployment script: Build, push, and deploy to Azure
# Usage: ./scripts/deploy-to-azure.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ACR_NAME="cloudsoundacrmgo77h"
REGISTRY="${ACR_NAME}.azurecr.io"
NAMESPACE="cloudsound"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CloudSound Azure Deployment${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Step 1: Login to ACR
echo -e "${YELLOW}Step 1: Logging into Azure Container Registry...${NC}"
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
echo "$ACR_PASSWORD" | sudo docker login $REGISTRY -u $ACR_NAME --password-stdin > /dev/null 2>&1
echo -e "${GREEN}✓ Logged into ACR${NC}\n"

# Step 2: Build and push images
echo -e "${YELLOW}Step 2: Building and pushing Docker images...${NC}"
export REGISTRY=$REGISTRY
COMMIT=$(git rev-parse --short HEAD)
echo -e "Building images for commit: ${BLUE}$COMMIT${NC}\n"

# Backend services
BACKEND_SERVICES=(
    "api-gateway"
    "authentication"
    "radio-streaming"
    "concert-management"
    "analytics"
    "music-discovery"
    "event-manager"
)

for service in "${BACKEND_SERVICES[@]}"; do
    echo -e "${YELLOW}📦 Building ${service}...${NC}"
    sudo docker build \
        -f "backend/${service}/Dockerfile" \
        -t "${REGISTRY}/${service}:latest" \
        -t "${REGISTRY}/${service}:${COMMIT}" \
        "backend/${service}" > /dev/null 2>&1
    
    echo -e "${YELLOW}⬆️  Pushing ${service}...${NC}"
    sudo docker push "${REGISTRY}/${service}:latest" > /dev/null 2>&1
    sudo docker push "${REGISTRY}/${service}:${COMMIT}" > /dev/null 2>&1
    echo -e "${GREEN}✓ ${service} complete${NC}"
done

# Frontend
echo -e "${YELLOW}📦 Building frontend...${NC}"
sudo docker build \
    -f "frontend/Dockerfile" \
    -t "${REGISTRY}/frontend:latest" \
    -t "${REGISTRY}/frontend:${COMMIT}" \
    ./frontend > /dev/null 2>&1

echo -e "${YELLOW}⬆️  Pushing frontend...${NC}"
sudo docker push "${REGISTRY}/frontend:latest" > /dev/null 2>&1
sudo docker push "${REGISTRY}/frontend:${COMMIT}" > /dev/null 2>&1
echo -e "${GREEN}✓ Frontend complete${NC}\n"

# Step 3: Update Facebook secrets if values-secrets.yaml exists
SECRETS_FILE="infrastructure/helm/cloudsound/values-secrets.yaml"
if [ -f "$SECRETS_FILE" ]; then
    echo -e "${YELLOW}Step 3a: Updating Facebook secrets...${NC}"
    # Extract Facebook credentials
    if command -v yq &> /dev/null; then
        FB_TOKEN=$(yq eval '.secrets.facebookAccessToken' "$SECRETS_FILE" 2>/dev/null || echo "")
        FB_PAGE_IDS=$(yq eval '.secrets.facebookPageIds' "$SECRETS_FILE" 2>/dev/null || echo "")
    else
        FB_TOKEN=$(grep "facebookAccessToken:" "$SECRETS_FILE" | sed 's/.*facebookAccessToken:[[:space:]]*"\(.*\)".*/\1/' | head -1)
        FB_PAGE_IDS=$(grep "facebookPageIds:" "$SECRETS_FILE" | sed 's/.*facebookPageIds:[[:space:]]*"\(.*\)".*/\1/' | head -1)
    fi
    
    if [ -n "$FB_TOKEN" ] && [ "$FB_TOKEN" != "null" ] && [ "$FB_TOKEN" != "" ]; then
        # Update secret
        kubectl create secret generic cloudsound-secrets -n $NAMESPACE \
            --from-literal=facebook-access-token="$FB_TOKEN" \
            --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
        
        # Update deployment environment variables
        kubectl set env deployment/cloudsound-event-manager -n $NAMESPACE \
            FACEBOOK_PAGE_IDS="$FB_PAGE_IDS" > /dev/null 2>&1
        
        # Ensure FACEBOOK_ACCESS_TOKEN env var exists
        kubectl patch deployment cloudsound-event-manager -n $NAMESPACE --type='json' \
            -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "FACEBOOK_ACCESS_TOKEN", "valueFrom": {"secretKeyRef": {"name": "cloudsound-secrets", "key": "facebook-access-token"}}}}]' \
            > /dev/null 2>&1 || true
        
        echo -e "${GREEN}✓ Facebook secrets updated${NC}\n"
    fi
fi

# Step 3: Restart deployments to pull new images
echo -e "${YELLOW}Step 3: Restarting deployments to pull new images...${NC}"
kubectl rollout restart deployment \
    cloudsound-api-gateway \
    cloudsound-authentication \
    cloudsound-radio-streaming \
    cloudsound-concert-management \
    cloudsound-analytics \
    cloudsound-music-discovery \
    cloudsound-event-manager \
    cloudsound-frontend \
    -n $NAMESPACE > /dev/null 2>&1

echo -e "${GREEN}✓ Deployments restarted${NC}\n"

# Step 4: Wait for rollout
echo -e "${YELLOW}Step 4: Waiting for deployments to complete...${NC}"
sleep 5
kubectl rollout status deployment/cloudsound-api-gateway -n $NAMESPACE --timeout=5m > /dev/null 2>&1 || true
kubectl rollout status deployment/cloudsound-authentication -n $NAMESPACE --timeout=5m > /dev/null 2>&1 || true
kubectl rollout status deployment/cloudsound-frontend -n $NAMESPACE --timeout=5m > /dev/null 2>&1 || true

# Step 5: Verify deployment
echo -e "\n${YELLOW}Step 5: Verifying deployment...${NC}"
echo ""
kubectl get pods -n $NAMESPACE | grep -E "NAME|api-gateway|authentication|radio|concert|analytics|music|event|frontend" | head -10

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"
echo -e "Images built with commit: ${BLUE}$COMMIT${NC}"
echo -e "Registry: ${BLUE}$REGISTRY${NC}"
echo -e "\nCheck pod status: ${YELLOW}kubectl get pods -n $NAMESPACE${NC}"
