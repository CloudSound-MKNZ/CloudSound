#!/bin/bash
# Phase 3 Testing Script - User Story 1 (Radio Streaming)
# This script tests all Phase 3 functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Phase 3 Testing - User Story 1: Radio Streaming"
echo "=================================================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Check if infrastructure is up
if ! docker compose -f infrastructure/docker/docker-compose.dev.yml ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠️  Infrastructure services not running. Starting them...${NC}"
    docker compose -f infrastructure/docker/docker-compose.dev.yml up -d
    echo "⏳ Waiting for services to be ready..."
    sleep 15
fi
echo -e "${GREEN}✅ Infrastructure services are running${NC}"

# Check if services are running
echo ""
echo "🔍 Checking if services are running..."

# Check radio-streaming service
if curl -s http://localhost:8004/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Radio Streaming Service (port 8004) is running${NC}"
else
    echo -e "${RED}❌ Radio Streaming Service is NOT running on port 8004${NC}"
    echo "   Start it with: cd backend/radio-streaming && uvicorn src.main:app --reload --port 8004"
    exit 1
fi

# Check analytics service
if curl -s http://localhost:8007/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Analytics Service (port 8007) is running${NC}"
else
    echo -e "${YELLOW}⚠️  Analytics Service is NOT running on port 8007${NC}"
    echo "   Start it with: cd backend/analytics && uvicorn src.main:app --reload --port 8007"
fi

echo ""
echo "🧪 Running API Tests..."
echo "----------------------"

# Test 1: Health check
echo -n "Test 1: Health check... "
if curl -s http://localhost:8004/health | grep -q "healthy"; then
    echo -e "${GREEN}✅ PASSED${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    exit 1
fi

# Test 2: List radio stations
echo -n "Test 2: List radio stations... "
STATIONS_RESPONSE=$(curl -s http://localhost:8004/api/v1/radio/stations)
if echo "$STATIONS_RESPONSE" | grep -q "stations\|\[\]"; then
    echo -e "${GREEN}✅ PASSED${NC}"
    echo "   Response: $(echo "$STATIONS_RESPONSE" | jq -r '.stations | length' 2>/dev/null || echo "N/A") stations found"
else
    echo -e "${RED}❌ FAILED${NC}"
    echo "   Response: $STATIONS_RESPONSE"
    exit 1
fi

# Test 3: Get station details (if stations exist)
STATION_ID=$(echo "$STATIONS_RESPONSE" | jq -r '.stations[0].id' 2>/dev/null || echo "")
if [ -n "$STATION_ID" ] && [ "$STATION_ID" != "null" ]; then
    echo -n "Test 3: Get station details... "
    if curl -s "http://localhost:8004/api/v1/radio/stations/$STATION_ID" | grep -q "id\|name"; then
        echo -e "${GREEN}✅ PASSED${NC}"
    else
        echo -e "${YELLOW}⚠️  Station details endpoint returned unexpected response${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No stations found - skipping station details test${NC}"
    echo "   Run: python scripts/seed-mock-data.py"
fi

# Test 4: Metrics endpoint
echo -n "Test 4: Prometheus metrics... "
if curl -s http://localhost:8004/metrics | grep -q "http_requests_total\|radio_streaming"; then
    echo -e "${GREEN}✅ PASSED${NC}"
else
    echo -e "${YELLOW}⚠️  Metrics endpoint returned unexpected response${NC}"
fi

# Test 5: API documentation
echo -n "Test 5: API documentation... "
if curl -s http://localhost:8004/docs | grep -q "swagger\|openapi"; then
    echo -e "${GREEN}✅ PASSED${NC}"
else
    echo -e "${YELLOW}⚠️  API docs endpoint returned unexpected response${NC}"
fi

echo ""
echo "🔍 Checking Database..."
echo "----------------------"

# Check if database has data
echo -n "Checking database connection... "
if PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASSED${NC}"
    
    # Check if tables exist
    echo -n "Checking if tables exist... "
    TABLE_COUNT=$(PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('artists', 'tracks', 'radio_stations', 'station_tracks');" 2>/dev/null | tr -d ' ')
    if [ "$TABLE_COUNT" -ge "4" ]; then
        echo -e "${GREEN}✅ PASSED (found $TABLE_COUNT tables)${NC}"
    else
        echo -e "${YELLOW}⚠️  Some tables missing (found $TABLE_COUNT/4)${NC}"
        echo "   Run migrations: cd backend/shared/db && alembic upgrade head"
    fi
    
    # Check if data exists
    echo -n "Checking if data exists... "
    ARTIST_COUNT=$(PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -t -c "SELECT COUNT(*) FROM artists;" 2>/dev/null | tr -d ' ')
    if [ "$ARTIST_COUNT" -gt "0" ]; then
        echo -e "${GREEN}✅ PASSED (found $ARTIST_COUNT artists)${NC}"
    else
        echo -e "${YELLOW}⚠️  No data found${NC}"
        echo "   Run: python scripts/seed-mock-data.py"
    fi
else
    echo -e "${RED}❌ FAILED - Cannot connect to database${NC}"
    echo "   Make sure PostgreSQL is running: docker compose -f infrastructure/docker/docker-compose.dev.yml ps postgres"
fi

echo ""
echo "📊 Summary"
echo "----------"
echo -e "${GREEN}✅ Phase 3 API tests completed${NC}"
echo ""
echo "Next steps:"
echo "  1. Open frontend: http://localhost:5173"
echo "  2. Navigate to: http://localhost:5173/radio"
echo "  3. Select a radio station"
echo "  4. Click Play to test audio streaming"
echo "  5. Verify crossfade transitions between tracks"
echo ""
echo "Manual testing checklist:"
echo "  [ ] Frontend loads radio stations"
echo "  [ ] Can select a station"
echo "  [ ] Audio player appears"
echo "  [ ] Can play audio (if MP3 files are available)"
echo "  [ ] Crossfade works between tracks"
echo "  [ ] Playback events are tracked (check Kafka/analytics)"
echo ""

