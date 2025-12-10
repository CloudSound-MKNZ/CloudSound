#!/bin/bash
# Stop all CloudSound services and optionally infrastructure

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}🛑 Stopping CloudSound services...${NC}"
echo ""

# Parse arguments
STOP_INFRA=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --infra)
            STOP_INFRA=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--infra]"
            exit 1
            ;;
    esac
done

# Stop backend services
echo "Stopping backend services..."
pkill -f "uvicorn.*radio-streaming.*8004" 2>/dev/null && echo -e "${GREEN}✅ Radio Streaming stopped${NC}" || echo "  Radio Streaming not running"
pkill -f "uvicorn.*analytics.*8007" 2>/dev/null && echo -e "${GREEN}✅ Analytics stopped${NC}" || echo "  Analytics not running"

# Stop frontend
echo "Stopping frontend..."
pkill -f "vite.*frontend" 2>/dev/null && echo -e "${GREEN}✅ Frontend stopped${NC}" || echo "  Frontend not running"
pkill -f "npm.*dev" 2>/dev/null || true

# Clean up PID files
rm -f /tmp/cloudsound-*.pid 2>/dev/null || true

# Optionally stop infrastructure
if [ "$STOP_INFRA" = true ]; then
    echo ""
    echo "Stopping infrastructure..."
    
    # Stop docker-compose (default for development)
    COMPOSE_FILE="infrastructure/docker/docker-compose.dev.yml"
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" down 2>/dev/null && echo -e "${GREEN}✅ Docker infrastructure stopped${NC}" || echo "  Docker infrastructure not running"
    fi
    
    # Note: k3s deployments must be stopped manually with kubectl
    if kubectl cluster-info &> /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  k3s cluster detected but not stopped${NC}"
        echo "   Stop k3s deployments manually: kubectl delete -f infrastructure/kubernetes/"
    fi
else
    echo ""
    echo -e "${YELLOW}💡 Infrastructure (Docker Compose) is still running${NC}"
    echo "   To stop infrastructure: ./scripts/stop.sh --infra"
fi

echo ""
echo -e "${GREEN}✅ All services stopped${NC}"

