#!/bin/bash

# Option B (multi-repo): Build and push only images that live in this repo:
# - frontend
# - cloudsound-shared (migrations)
# Backend service images are built and pushed from their own repos.
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

echo -e "${GREEN}Building and pushing images to ${REGISTRY} (Option B: frontend + migrations only)${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Build and push migrations (cloudsound-shared)
echo -e "${YELLOW}Building cloudsound-shared (migrations)...${NC}"
docker build \
    -f "backend/shared/Dockerfile" \
    -t "${REGISTRY}/cloudsound-shared:latest" \
    -t "${REGISTRY}/cloudsound-shared:$(git rev-parse --short HEAD)" \
    ./backend/shared

echo -e "${YELLOW}Pushing cloudsound-shared...${NC}"
docker push "${REGISTRY}/cloudsound-shared:latest"
docker push "${REGISTRY}/cloudsound-shared:$(git rev-parse --short HEAD)"
echo -e "${GREEN}✓ cloudsound-shared complete${NC}"

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

echo -e "\n${GREEN}Frontend and migrations built and pushed. Backend images are built from service repos (see docs/MULTIREPO_DEPLOY.md). 🚀${NC}"

