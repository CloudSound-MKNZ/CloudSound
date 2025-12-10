#!/bin/bash
# Start CloudSound development environment
# Uses Docker Compose for local development (default)
# k3s/Kubernetes is for production deployment only

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}🚀 CloudSound - Starting Development Environment${NC}"
echo "=================================================="
echo ""

# Parse arguments
START_SERVICES=true
START_INFRA=true
SEED_DATA=true
USE_K3S=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-services)
            START_SERVICES=false
            shift
            ;;
        --no-infra)
            START_INFRA=false
            shift
            ;;
        --no-seed)
            SEED_DATA=false
            shift
            ;;
        --k3s)
            USE_K3S=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-services] [--no-infra] [--no-seed] [--k3s]"
            echo ""
            echo "Options:"
            echo "  --no-services  Skip starting backend/frontend services"
            echo "  --no-infra     Skip starting infrastructure"
            echo "  --no-seed      Skip seeding mock data"
            echo "  --k3s          Use k3s instead of Docker Compose (requires k3s already running)"
            echo ""
            echo "Note: k3s is NOT automatically deployed. It must be installed and running separately."
            echo "      Docker Compose is the default for local development."
            exit 1
            ;;
    esac
done

# Step 1: Start Infrastructure
if [ "$START_INFRA" = true ]; then
    echo -e "${YELLOW}📦 Starting infrastructure services...${NC}"
    
    if [ "$USE_K3S" = true ]; then
        # k3s mode - check if k3s is running
        if ! kubectl cluster-info &> /dev/null 2>&1; then
            echo -e "${RED}❌ k3s cluster not detected${NC}"
            echo ""
            echo "k3s must be installed and running before using --k3s flag."
            echo "Install k3s: https://k3s.io/"
            echo "Or use Docker Compose (default): ./scripts/start.sh"
            exit 1
        fi
        echo "  Using k3s cluster (production mode)"
        echo -e "${YELLOW}⚠️  k3s deployments must be applied separately${NC}"
        echo -e "${GREEN}✅ k3s cluster detected${NC}"
    else
        # Docker Compose mode (default for development)
        COMPOSE_FILE="infrastructure/docker/docker-compose.dev.yml"
        if docker compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep -q "Up"; then
            echo -e "${GREEN}✅ Infrastructure already running${NC}"
        else
            echo "  Starting Docker Compose services..."
            docker compose -f "$COMPOSE_FILE" up -d
            echo "⏳ Waiting for services to be ready..."
            sleep 15
            echo -e "${GREEN}✅ Infrastructure started${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⏭️  Skipping infrastructure startup${NC}"
fi

# Step 2: Setup database (migrations)
echo ""
echo -e "${YELLOW}🗄️  Setting up database...${NC}"

# Setup virtual environment for migrations
VENV_DIR="${PROJECT_ROOT}/.venv-migrations"
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating virtual environment for migrations..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip > /dev/null 2>&1
    pip install -q -r "${PROJECT_ROOT}/backend/shared/requirements.txt"
    pip install -q alembic psycopg2-binary
    echo -e "${GREEN}✅ Virtual environment created${NC}"
else
    source "$VENV_DIR/bin/activate"
    if ! python -c "import psycopg2" 2>/dev/null; then
        pip install -q psycopg2-binary
    fi
fi

export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH}"

# Run migrations
echo "📊 Running database migrations..."
cd backend/shared/db
alembic upgrade head > /dev/null 2>&1 || echo -e "${YELLOW}⚠️  Migrations may have already been applied${NC}"
cd "$PROJECT_ROOT"

# Seed mock data
if [ "$SEED_DATA" = true ]; then
    echo "🌱 Seeding mock data..."
    python scripts/seed-mock-data.py 2>/dev/null | grep -q "seeded successfully" && echo -e "${GREEN}✅ Mock data seeded${NC}" || echo -e "${YELLOW}⚠️  Data may already exist${NC}"
fi

deactivate 2>/dev/null || true

# Step 3: Start Services (optional)
if [ "$START_SERVICES" = true ]; then
    echo ""
    echo -e "${YELLOW}🎵 Starting backend services...${NC}"
    echo ""
    echo -e "${BLUE}💡 Tip: Services can be started manually in separate terminals:${NC}"
    echo "   Radio Streaming: cd backend/radio-streaming && uvicorn src.main:app --reload --port 8004"
    echo "   Analytics:        cd backend/analytics && uvicorn src.main:app --reload --port 8007"
    echo "   Frontend:         cd frontend && npm run dev"
    echo ""
    echo -e "${YELLOW}⚠️  Auto-starting services in background (use --no-services to skip)${NC}"
    
    # Function to check if port is in use
    check_port() {
        local PORT=$1
        if command -v lsof >/dev/null 2>&1; then
            lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1
        elif command -v netstat >/dev/null 2>&1; then
            netstat -tuln 2>/dev/null | grep -q ":$PORT "
        elif command -v ss >/dev/null 2>&1; then
            ss -tuln 2>/dev/null | grep -q ":$PORT "
        else
            return 1
        fi
    }
    
    # Function to start a service
    start_service() {
        local SERVICE_NAME=$1
        local SERVICE_DIR=$2
        local PORT=$3
        
        if check_port $PORT; then
            echo -e "${YELLOW}⚠️  Port $PORT is already in use, skipping $SERVICE_NAME${NC}"
            return
        fi
        
        (
            cd "$SERVICE_DIR"
            if [ ! -d "venv" ]; then
                python3 -m venv venv
                source venv/bin/activate
                pip install --upgrade pip > /dev/null 2>&1
                pip install -q -r "${PROJECT_ROOT}/backend/shared/requirements.txt"
                pip install -q -r requirements.txt
            else
                source venv/bin/activate
            fi
            export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH}"
            uvicorn src.main:app --reload --port "$PORT" --host 0.0.0.0 > "/tmp/cloudsound-${SERVICE_NAME}.log" 2>&1 &
            echo $! > "/tmp/cloudsound-${SERVICE_NAME}.pid"
        )
        
        local PID=$(cat "/tmp/cloudsound-${SERVICE_NAME}.pid" 2>/dev/null || echo "")
        if [ -n "$PID" ]; then
            echo -e "${GREEN}✅ $SERVICE_NAME started (PID: $PID, Port: $PORT)${NC}"
            sleep 2
        fi
    }
    
    start_service "radio-streaming" "${PROJECT_ROOT}/backend/radio-streaming" 8004
    start_service "analytics" "${PROJECT_ROOT}/backend/analytics" 8007
    
    # Start frontend
    echo ""
    echo -e "${YELLOW}🎨 Starting frontend...${NC}"
    cd frontend
    if [ ! -d "node_modules" ]; then
        echo "📦 Installing frontend dependencies..."
        npm install > /dev/null 2>&1
    fi
    npm run dev > "/tmp/cloudsound-frontend.log" 2>&1 &
    FRONTEND_PID=$!
    cd "$PROJECT_ROOT"
    sleep 3
    echo -e "${GREEN}✅ Frontend started (PID: $FRONTEND_PID)${NC}"
    
    echo ""
    echo -e "${GREEN}✅ All services started!${NC}"
    echo ""
    echo -e "${BLUE}🌐 Access Points:${NC}"
    echo "  Frontend:        http://localhost:5173"
    echo "  Radio API:      http://localhost:8004"
    echo "  Radio Docs:     http://localhost:8004/docs"
    echo "  Analytics API:  http://localhost:8007"
    echo "  Analytics Docs: http://localhost:8007/docs"
    echo ""
    echo -e "${YELLOW}💡 Logs: /tmp/cloudsound-*.log${NC}"
    echo -e "${YELLOW}💡 Use ./scripts/stop.sh to stop all services${NC}"
else
    echo ""
    echo -e "${GREEN}✅ Setup complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "  1. Start services manually in separate terminals"
    echo "  2. Or run: ./scripts/start.sh (without --no-services)"
fi

echo ""

