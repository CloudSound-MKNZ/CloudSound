#!/bin/bash

# Update Facebook secrets in Helm release
# Usage: ./scripts/update-facebook-secrets.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RELEASE_NAME="cloudsound"
NAMESPACE="cloudsound"
HELM_CHART_DIR="infrastructure/helm/cloudsound"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Update Facebook Secrets in Helm${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Check if values-secrets.yaml exists
SECRETS_FILE="$HELM_CHART_DIR/values-secrets.yaml"
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}Error: $SECRETS_FILE not found${NC}"
    echo -e "${YELLOW}Please create it with your Facebook credentials${NC}"
    exit 1
fi

echo -e "${YELLOW}Reading Facebook credentials from $SECRETS_FILE...${NC}"

# Extract Facebook token and page IDs
if command -v yq &> /dev/null; then
    FB_TOKEN=$(yq eval '.secrets.facebookAccessToken' "$SECRETS_FILE" 2>/dev/null || echo "")
    FB_PAGE_IDS=$(yq eval '.secrets.facebookPageIds' "$SECRETS_FILE" 2>/dev/null || echo "")
else
    # Fallback to grep/sed if yq is not available
    FB_TOKEN=$(grep "facebookAccessToken:" "$SECRETS_FILE" | sed 's/.*facebookAccessToken:[[:space:]]*"\(.*\)".*/\1/' | head -1)
    FB_PAGE_IDS=$(grep "facebookPageIds:" "$SECRETS_FILE" | sed 's/.*facebookPageIds:[[:space:]]*"\(.*\)".*/\1/' | head -1)
fi

if [ -z "$FB_TOKEN" ] || [ "$FB_TOKEN" == "null" ] || [ "$FB_TOKEN" == "" ]; then
    echo -e "${RED}Error: Facebook access token not found in $SECRETS_FILE${NC}"
    exit 1
fi

if [ -z "$FB_PAGE_IDS" ] || [ "$FB_PAGE_IDS" == "null" ] || [ "$FB_PAGE_IDS" == "" ]; then
    echo -e "${RED}Error: Facebook page IDs not found in $SECRETS_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found Facebook credentials${NC}"
echo -e "  Token: ${BLUE}${FB_TOKEN:0:20}...${NC}"
echo -e "  Page IDs: ${BLUE}$FB_PAGE_IDS${NC}\n"

# Update Helm release
echo -e "${YELLOW}Updating Helm release $RELEASE_NAME...${NC}"
cd "$HELM_CHART_DIR"

helm upgrade "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --reuse-values \
    --set secrets.facebookAccessToken="$FB_TOKEN" \
    --set secrets.facebookPageIds="$FB_PAGE_IDS" \
    --wait

echo -e "\n${GREEN}✓ Helm release updated${NC}"

# Restart event-manager to pick up new secrets
echo -e "\n${YELLOW}Restarting event-manager deployment...${NC}"
kubectl rollout restart deployment/cloudsound-event-manager -n "$NAMESPACE" > /dev/null 2>&1
kubectl rollout status deployment/cloudsound-event-manager -n "$NAMESPACE" --timeout=2m > /dev/null 2>&1 || true

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Facebook Secrets Updated!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "Verify configuration: ${YELLOW}curl http://api.cloudsound.local/api/v1/events/status${NC}"
