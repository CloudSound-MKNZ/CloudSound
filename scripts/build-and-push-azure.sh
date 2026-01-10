#!/bin/bash

# Build and push all CloudSound Docker images to Azure Container Registry
# Usage: ./scripts/build-and-push-azure.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if REGISTRY is set
if [ -z "$REGISTRY" ]; then
    echo -e "${RED}Error: REGISTRY environment variable not set${NC}"
    echo "Please set it with: export REGISTRY=<your-acr-name>.azurecr.io"
    echo "Example: export REGISTRY=cloudsoundacr123456.azurecr.io"
    exit 1
fi

echo -e "${GREEN}Building and pushing images to ${REGISTRY}${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Array of backend services
BACKEND_SERVICES=(
    "api-gateway"
    "authentication"
    "radio-streaming"
    "concert-management"
    "analytics"
    "music-discovery"
    "event-manager"
)

# Build and push backend services
for service in "${BACKEND_SERVICES[@]}"; do
    echo -e "${YELLOW}Building ${service}...${NC}"
    
    docker build \
        -f "backend/${service}/Dockerfile" \
        -t "${REGISTRY}/${service}:latest" \
        -t "${REGISTRY}/${service}:$(git rev-parse --short HEAD)" \
        "backend/${service}"
    
    echo -e "${YELLOW}Pushing ${service}...${NC}"
    docker push "${REGISTRY}/${service}:latest"
    docker push "${REGISTRY}/${service}:$(git rev-parse --short HEAD)"
    
    echo -e "${GREEN}✓ ${service} complete${NC}"
done

# Build and push frontend
echo -e "${YELLOW}Building frontend...${NC}"
docker build \
    -f "frontend/Dockerfile" \
    -t "${REGISTRY}/frontend:latest" \
    -t "${REGISTRY}/frontend:$(git rev-parse --short HEAD)" \
    ./frontend

echo -e "${YELLOW}Pushing frontend...${NC}"
docker push "${REGISTRY}/frontend:latest"
docker push "${REGISTRY}/frontend:$(git rev-parse --short HEAD)"

echo -e "${GREEN}✓ Frontend complete${NC}"

# List all images in ACR
echo -e "\n${GREEN}Images in Azure Container Registry:${NC}"
ACR_NAME=$(echo $REGISTRY | cut -d'.' -f1)
az acr repository list --name $ACR_NAME --output table

echo -e "\n${GREEN}All images built and pushed successfully! 🚀${NC}"

