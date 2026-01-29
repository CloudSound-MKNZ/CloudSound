#!/bin/bash

# Check Facebook token configuration in Azure deployment
# Usage: ./scripts/check-facebook-config.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE="cloudsound"

echo -e "${YELLOW}Checking Facebook token configuration in Azure...${NC}\n"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured${NC}"
    echo "Run: az aks get-credentials --resource-group cloudsound-rg --name cloudsound-aks"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}Error: Namespace $NAMESPACE does not exist${NC}"
    exit 1
fi

# Check if event-manager deployment exists
if ! kubectl get deployment -n $NAMESPACE cloudsound-event-manager &> /dev/null; then
    echo -e "${RED}Error: event-manager deployment not found${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Checking Kubernetes secret...${NC}"
if kubectl get secret -n $NAMESPACE cloudsound-secrets &> /dev/null; then
    if kubectl get secret -n $NAMESPACE cloudsound-secrets -o jsonpath='{.data.facebook-access-token}' &> /dev/null; then
        FB_TOKEN_SECRET=$(kubectl get secret -n $NAMESPACE cloudsound-secrets -o jsonpath='{.data.facebook-access-token}' | base64 -d 2>/dev/null || echo "")
        if [ -n "$FB_TOKEN_SECRET" ]; then
            echo -e "${GREEN}✓ Facebook token found in Kubernetes secret${NC}"
            echo -e "  Token preview: ${FB_TOKEN_SECRET:0:20}..."
        else
            echo -e "${RED}✗ Facebook token secret exists but is empty${NC}"
        fi
    else
        echo -e "${RED}✗ Facebook token not found in Kubernetes secret${NC}"
    fi
else
    echo -e "${RED}✗ cloudsound-secrets secret not found${NC}"
fi

echo -e "\n${YELLOW}2. Checking event-manager pod environment variables...${NC}"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=event-manager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_NAME" ]; then
    FB_TOKEN_ENV=$(kubectl exec -n $NAMESPACE $POD_NAME -- env | grep FACEBOOK_ACCESS_TOKEN || echo "")
    FB_PAGE_IDS_ENV=$(kubectl exec -n $NAMESPACE $POD_NAME -- env | grep FACEBOOK_PAGE_IDS || echo "")
    USE_MOCK_ENV=$(kubectl exec -n $NAMESPACE $POD_NAME -- env | grep USE_MOCK_APIS || echo "")
    
    if [ -n "$FB_TOKEN_ENV" ]; then
        echo -e "${GREEN}✓ FACEBOOK_ACCESS_TOKEN is set in pod${NC}"
        echo -e "  $FB_TOKEN_ENV"
    else
        echo -e "${RED}✗ FACEBOOK_ACCESS_TOKEN not set in pod${NC}"
    fi
    
    if [ -n "$FB_PAGE_IDS_ENV" ]; then
        echo -e "${GREEN}✓ FACEBOOK_PAGE_IDS is set in pod${NC}"
        echo -e "  $FB_PAGE_IDS_ENV"
    else
        echo -e "${RED}✗ FACEBOOK_PAGE_IDS not set in pod${NC}"
    fi
    
    if [ -n "$USE_MOCK_ENV" ]; then
        echo -e "${YELLOW}  $USE_MOCK_ENV${NC}"
        if echo "$USE_MOCK_ENV" | grep -q "USE_MOCK_APIS=false"; then
            echo -e "${GREEN}✓ Mock APIs are disabled (real API enabled)${NC}"
        else
            echo -e "${RED}✗ Mock APIs are enabled (real API disabled)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ USE_MOCK_APIS not explicitly set${NC}"
    fi
else
    echo -e "${RED}✗ event-manager pod not found${NC}"
fi

echo -e "\n${YELLOW}3. Checking event-manager service status...${NC}"

# First try: Check via kubectl exec (more reliable)
SKIP_PORT_FORWARD=false
if [ -n "$POD_NAME" ]; then
    echo -e "${YELLOW}  Trying direct pod access...${NC}"
    # Try Python first (more likely to be available)
    STATUS_RESPONSE=$(kubectl exec -n $NAMESPACE $POD_NAME -- python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8002/api/v1/events/status').read().decode())" 2>/dev/null || echo "")
    
    # Fallback to curl if Python fails
    if [ -z "$STATUS_RESPONSE" ] || [ "$STATUS_RESPONSE" = "null" ]; then
        STATUS_RESPONSE=$(kubectl exec -n $NAMESPACE $POD_NAME -- curl -s http://localhost:8002/api/v1/events/status 2>/dev/null || echo "")
    fi
    
    if [ -n "$STATUS_RESPONSE" ] && [ "$STATUS_RESPONSE" != "null" ] && echo "$STATUS_RESPONSE" | grep -q "mock_mode"; then
        echo -e "${GREEN}✓ Service is responding (via pod exec)${NC}"
        MOCK_MODE=$(echo "$STATUS_RESPONSE" | grep -o '"mock_mode":[^,}]*' | cut -d: -f2 | tr -d ' "' || echo "")
        if [ "$MOCK_MODE" = "false" ]; then
            echo -e "${GREEN}✓ Service reports mock_mode=false (real API enabled)${NC}"
        elif [ "$MOCK_MODE" = "true" ]; then
            echo -e "${RED}✗ Service reports mock_mode=true (mock API enabled)${NC}"
        fi
        echo -e "  Response: $(echo "$STATUS_RESPONSE" | head -c 200)..."
        SKIP_PORT_FORWARD=true
    else
        echo -e "${YELLOW}  Pod exec method failed or returned invalid response, trying port-forward...${NC}"
        SKIP_PORT_FORWARD=false
    fi
fi

if [ "$SKIP_PORT_FORWARD" != "true" ]; then
echo -e "\n${YELLOW}3b. Checking event-manager service status endpoint (via port-forward)...${NC}"
SERVICE_PORT=$(kubectl get svc -n $NAMESPACE cloudsound-event-manager -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
SERVICE_URL=$(kubectl get svc -n $NAMESPACE cloudsound-event-manager -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
PORT_FORWARD_PID=""

if [ -z "$SERVICE_URL" ]; then
    # Try to port-forward if no LoadBalancer IP
    echo -e "${YELLOW}  No external IP, checking via port-forward...${NC}"
    
    # Try service port-forward first
    if kubectl port-forward -n $NAMESPACE svc/cloudsound-event-manager 8002:$SERVICE_PORT > /tmp/port-forward.log 2>&1 &
    then
        PORT_FORWARD_PID=$!
        echo -e "  Port-forward started (PID: $PORT_FORWARD_PID)"
        sleep 3  # Give it more time to establish
        
        # Check if port-forward is still running
        if ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
            echo -e "${YELLOW}  Port-forward failed, trying direct pod port-forward...${NC}"
            PORT_FORWARD_PID=""
            
            # Fallback: port-forward directly to pod
            if [ -n "$POD_NAME" ]; then
                if kubectl port-forward -n $NAMESPACE $POD_NAME 8002:8002 > /tmp/port-forward.log 2>&1 &
                then
                    PORT_FORWARD_PID=$!
                    sleep 3
                fi
            fi
        fi
        
        SERVICE_URL="localhost:8002"
    else
        echo -e "${YELLOW}  Could not start port-forward${NC}"
    fi
fi

if [ -n "$SERVICE_URL" ]; then
    # Try curl with timeout
    STATUS_RESPONSE=$(curl -s --max-time 5 "http://$SERVICE_URL/api/v1/events/status" 2>/dev/null || echo "")
    
    if [ -n "$STATUS_RESPONSE" ] && [ "$STATUS_RESPONSE" != "null" ]; then
        echo -e "${GREEN}✓ Service is responding${NC}"
        MOCK_MODE=$(echo "$STATUS_RESPONSE" | grep -o '"mock_mode":[^,}]*' | cut -d: -f2 | tr -d ' "' || echo "")
        if [ "$MOCK_MODE" = "false" ]; then
            echo -e "${GREEN}✓ Service reports mock_mode=false (real API enabled)${NC}"
        elif [ "$MOCK_MODE" = "true" ]; then
            echo -e "${RED}✗ Service reports mock_mode=true (mock API enabled)${NC}"
        fi
        echo -e "  Response: $(echo "$STATUS_RESPONSE" | head -c 200)..."
    else
        echo -e "${YELLOW}⚠ Could not reach service status endpoint${NC}"
        if [ -n "$PORT_FORWARD_PID" ]; then
            echo -e "  Port-forward log:"
            tail -5 /tmp/port-forward.log 2>/dev/null || echo "  (no log available)"
        fi
        echo -e "  ${YELLOW}Tip: Try manually: kubectl port-forward -n $NAMESPACE svc/cloudsound-event-manager 8002:$SERVICE_PORT${NC}"
    fi
    
    if [ -n "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
        wait $PORT_FORWARD_PID 2>/dev/null || true
    fi
else
    echo -e "${YELLOW}⚠ Could not determine service URL or establish port-forward${NC}"
fi
fi  # End SKIP_PORT_FORWARD check

echo -e "\n${YELLOW}Summary:${NC}"
echo -e "To fix Facebook sync:"
echo -e "1. Ensure values-secrets.yaml contains your Facebook token"
echo -e "2. Redeploy with: ${GREEN}./scripts/azure-deploy-all.sh${NC}"
echo -e "3. Or manually update Helm: ${GREEN}helm upgrade cloudsound infrastructure/helm/cloudsound --set secrets.facebookAccessToken=\"YOUR_TOKEN\" --set secrets.facebookPageIds=\"YOUR_PAGE_IDS\"${NC}"
