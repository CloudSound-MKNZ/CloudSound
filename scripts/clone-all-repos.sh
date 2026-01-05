#!/bin/bash
# Clone all CloudSound repositories for multi-repo development
# Run this from the directory where you want your workspace

set -e

# Configuration
ORG="CloudSound-MKNZ"
REPOS=(
    "CloudSound"
    "cloudsound-shared"
    "cloudsound-radio-streaming"
    "cloudsound-concert-management"
    "cloudsound-authentication"
    "cloudsound-analytics"
    "cloudsound-admin-management"
    "cloudsound-api-gateway"
    "cloudsound-event-manager"
    "cloudsound-music-discovery"
)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🚀 CloudSound Multi-Repo Setup"
echo "==============================="
echo ""

# Check if we're in the right place
WORKSPACE_DIR=$(pwd)
echo "Workspace directory: $WORKSPACE_DIR"
echo ""

# Clone or update repos
for repo in "${REPOS[@]}"; do
    if [ -d "$repo" ]; then
        echo -e "${YELLOW}📁 $repo already exists, pulling latest...${NC}"
        cd "$repo"
        git pull origin main || git pull origin master || echo "  (no remote to pull)"
        cd ..
    else
        echo -e "${GREEN}📥 Cloning $repo...${NC}"
        git clone "git@github.com:$ORG/$repo.git" || git clone "https://github.com/$ORG/$repo.git"
    fi
done

echo ""
echo "==============================="
echo -e "${GREEN}✅ All repositories ready!${NC}"
echo ""
echo "To open in Cursor IDE:"
echo "  cursor CloudSound/cloudsound.code-workspace"
echo ""
echo "To start infrastructure:"
echo "  cd CloudSound"
echo "  docker compose -f infrastructure/docker/docker-compose.dev.yml up -d"
echo ""

