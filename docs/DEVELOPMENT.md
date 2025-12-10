# CloudSound Development Guide

This guide covers environment configuration, local development setup, and testing procedures for the CloudSound platform.

> **Note**: For a quick start guide, see [QUICKSTART.md](QUICKSTART.md). For deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Table of Contents

1. [Environment Configuration](#environment-configuration)
2. [Local Development Setup](#local-development-setup)
3. [Testing Guide](#testing-guide)
4. [Troubleshooting](#troubleshooting)

---

## Environment Configuration

### Overview

CloudSound uses **environment-based configuration** managed through environment variables and configuration files. This approach follows industry best practices and is **NOT** managed through Git branches.

### Best Practices

#### ✅ DO:
- Use environment variables for configuration
- Use separate `.env` files for each environment
- Use ConfigMaps/Secrets in Kubernetes for production
- Use feature flags to enable/disable features per environment
- Keep example files (`.env.*.example`) in Git
- Use CI/CD pipelines to inject environment-specific values

#### ❌ DON'T:
- Use Git branches for environment configuration
- Commit actual `.env` files with secrets to Git
- Hardcode environment-specific values in code
- Use the same database/credentials across environments

### Environments

#### Development (`development`)
- **Purpose**: Local development on developer machines
- **Mock APIs**: Enabled
- **Mock Data**: Seeded automatically
- **Debug**: Enabled
- **Logging**: Text format, DEBUG level
- **Database**: Local PostgreSQL via Docker Compose
- **Setup**: `docker-compose -f infrastructure/docker/docker-compose.dev.yml up -d`

#### Test (`test`)
- **Purpose**: Automated testing and CI/CD
- **Mock APIs**: Enabled
- **Mock Data**: Seeded automatically
- **Debug**: Disabled
- **Logging**: JSON format, INFO level
- **Database**: Isolated test database
- **Setup**: `docker-compose -f infrastructure/docker/docker-compose.test.yml up -d`

#### Production (`production`)
- **Purpose**: Live production environment
- **Mock APIs**: Disabled (real APIs required)
- **Mock Data**: Never seeded
- **Debug**: Disabled
- **Logging**: JSON format, INFO level
- **Database**: Managed database service (RDS, etc.)
- **Setup**: Kubernetes deployment with ConfigMaps and Secrets

### Configuration Files

#### Environment Variable Files

| File | Purpose | Git Status |
|------|---------|------------|
| `.env.development.example` | Template for development | ✅ Committed |
| `.env.test.example` | Template for test | ✅ Committed |
| `.env.production.example` | Template for production | ✅ Committed |
| `.env.development` | Actual dev config | ❌ Gitignored |
| `.env.test` | Actual test config | ❌ Gitignored |
| `.env.production` | Actual prod config | ❌ Gitignored |

#### Setup Instructions

1. **Development**:
   ```bash
   cp .env.development.example .env.development
   # Edit .env.development with your local settings
   export ENVIRONMENT=development
   ```

2. **Test**:
   ```bash
   cp .env.test.example .env.test
   # Edit .env.test with test settings
   export ENVIRONMENT=test
   ```

3. **Production**:
   ```bash
   cp .env.production.example .env.production
   # Edit .env.production with production settings
   # Store secrets in secret manager (AWS Secrets Manager, etc.)
   export ENVIRONMENT=production
   ```

### Docker Compose Files

| File | Purpose | Environment |
|------|---------|-------------|
| `docker-compose.dev.yml` | Local development | Development |
| `docker-compose.test.yml` | Test environment | Test |
| `docker-compose.yml` | (Legacy) | Development |

#### Usage

```bash
# Development
docker-compose -f infrastructure/docker/docker-compose.dev.yml up -d

# Test
docker-compose -f infrastructure/docker/docker-compose.test.yml up -d
```

### Feature Flags

Feature flags are controlled via environment variables:

| Flag | Development | Test | Production |
|------|-------------|------|------------|
| `USE_MOCK_APIS` | `true` | `true` | `false` |
| `SEED_MOCK_DATA` | `true` | `true` | `false` |
| `DEBUG` | `true` | `false` | `false` |

### Mock Data Seeding

Mock data is **automatically seeded** in development and test environments, but **blocked** in production:

```bash
# Development/Test - works
ENVIRONMENT=development python scripts/seed-mock-data.py

# Production - blocked for safety
ENVIRONMENT=production python scripts/seed-mock-data.py
# ❌ ERROR: Cannot seed mock data in production environment!
```

### Kubernetes Configuration

In Kubernetes, environment configuration is managed via:

1. **ConfigMaps**: Non-sensitive configuration
   ```yaml
   # infrastructure/kubernetes/base/configmap.yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: cloudsound-config
   data:
     ENVIRONMENT: "production"
     LOG_LEVEL: "INFO"
   ```

2. **Secrets**: Sensitive data (passwords, API keys)
   ```yaml
   # infrastructure/kubernetes/base/secrets.yaml (NOT committed)
   apiVersion: v1
   kind: Secret
   metadata:
     name: cloudsound-secrets
   type: Opaque
   data:
     POSTGRES_PASSWORD: <base64-encoded>
     SECRET_KEY: <base64-encoded>
   ```

### Git Branch Strategy

**Branches are for CODE, not for configuration:**

- `main`: Production-ready code
- `develop`: Development branch
- `feature/*`: Feature branches
- `release/*`: Release preparation

**Configuration is environment-based, not branch-based.**

### Security Considerations

1. **Never commit secrets** to Git
2. **Use secret managers** in production (AWS Secrets Manager, HashiCorp Vault)
3. **Rotate secrets regularly**
4. **Use different credentials** for each environment
5. **Enable audit logging** in production

---

## Local Development Setup

### Prerequisites

- **Docker** and **Docker Compose** installed
- **Python 3.11+** (for backend services)
- **Node.js 20+** (for frontend)
- **PostgreSQL client tools** (optional, for database access)

### Quick Start

1. **Start Infrastructure**:
   ```bash
   docker compose -f infrastructure/docker/docker-compose.dev.yml up -d
   ```

2. **Run Database Migrations**:
   ```bash
   cd backend/shared/db
   alembic upgrade head
   cd ../../..
   ```

3. **Seed Mock Data** (optional):
   ```bash
   python scripts/seed-mock-data.py
   ```

4. **Start Backend Services**:
   
   **Radio Streaming Service** (port 8004):
   ```bash
   cd backend/radio-streaming
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   uvicorn src.main:app --reload --port 8004
   ```
   
   **Analytics Service** (port 8007):
   ```bash
   cd backend/analytics
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   uvicorn src.main:app --reload --port 8007
   ```
   
   **Concert Management Service** (port 8005):
   ```bash
   cd backend/concert-management
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   uvicorn src.main:app --reload --port 8005
   ```

5. **Start Frontend**:
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

### Service Ports

| Service | Port | URL |
|---------|------|-----|
| Frontend | 5173 | http://localhost:5173 |
| Radio Streaming | 8004 | http://localhost:8004 |
| Analytics | 8007 | http://localhost:8007 |
| Concert Management | 8005 | http://localhost:8005 |
| PostgreSQL | 5432 | localhost:5432 |
| Kafka | 9092 | localhost:9092 |
| RabbitMQ | 5672, 15672 | http://localhost:15672 |
| MinIO | 9000, 9001 | http://localhost:9001 |

---

## Testing Guide

### Quick Test Script

Run the automated test script:

```bash
./scripts/test-phase3.sh
```

This script will:
- ✅ Check if infrastructure services are running
- ✅ Verify backend services are accessible
- ✅ Test API endpoints
- ✅ Check database connectivity and data
- ✅ Verify metrics endpoints

### Manual Testing Steps

#### Prerequisites

1. **Start Infrastructure**:
   ```bash
   docker compose -f infrastructure/docker/docker-compose.dev.yml up -d
   ```

2. **Run Database Migrations**:
   ```bash
   cd backend/shared/db
   alembic upgrade head
   cd ../../..
   ```

3. **Seed Mock Data**:
   ```bash
   python scripts/seed-mock-data.py
   ```

4. **Start Backend Services** (see [Local Development Setup](#local-development-setup))

5. **Start Frontend**:
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

### Test Checklist

#### ✅ API Endpoints

1. **Health Check**
   ```bash
   curl http://localhost:8004/health
   ```
   Expected: `{"status": "healthy"}`

2. **List Radio Stations**
   ```bash
   curl http://localhost:8004/api/v1/radio/stations
   ```
   Expected: JSON array of radio stations

3. **Get Station Details**
   ```bash
   # Get a station ID from the list above, then:
   curl http://localhost:8004/api/v1/radio/stations/{STATION_ID}
   ```
   Expected: Station details with tracks

4. **Stream Endpoint** (for a specific track)
   ```bash
   curl -I http://localhost:8004/api/v1/radio/stream/{TRACK_ID}
   ```
   Expected: HTTP 200 or 206 (range request support)

5. **Metrics**
   ```bash
   curl http://localhost:8004/metrics
   ```
   Expected: Prometheus metrics in text format

6. **API Documentation**
   - Open: http://localhost:8004/docs
   - Verify all endpoints are documented
   - Try the "Try it out" feature

#### ✅ Frontend Testing

1. **Open Frontend**
   - Navigate to: http://localhost:5173
   - Should see the CloudSound homepage

2. **Radio Stations Page**
   - Navigate to: http://localhost:5173/radio
   - Should see list of radio stations
   - Stations should be organized by type (upcoming, past, genre)

3. **Station Selection**
   - Click on a radio station
   - Should navigate to station detail page
   - Should see station information and track list

4. **Audio Player**
   - Click "Play" button
   - Audio player should appear
   - Player should show current track information
   - Controls should be visible (play/pause, next, previous)

5. **Crossfade Testing** (if audio files are available)
   - Let a track play to completion
   - Next track should start with smooth crossfade
   - No gaps or abrupt transitions
   - Crossfade duration should be ~3 seconds

6. **Manual Track Navigation**
   - Click "Next" button
   - Track should change with crossfade
   - Click "Previous" button
   - Should go back to previous track

#### ✅ Database Verification

1. **Check Tables Exist**:
   ```bash
   PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "\dt"
   ```
   Should see: `artists`, `tracks`, `radio_stations`, `station_tracks`, `playback_events`

2. **Check Data**:
   ```bash
   PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "SELECT COUNT(*) FROM artists;"
   PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "SELECT COUNT(*) FROM tracks;"
   PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "SELECT COUNT(*) FROM radio_stations;"
   ```

#### ✅ Kafka Integration

1. **Check Kafka is Running**:
   ```bash
   docker compose -f infrastructure/docker/docker-compose.dev.yml ps kafka
   ```

2. **Verify Playback Events**:
   - Play a track in the frontend
   - Check analytics service logs for consumed events
   - Or check Kafka topics (requires Kafka tools):
     ```bash
     # If you have kafka-console-consumer available
     docker exec -it $(docker ps -q -f name=kafka) kafka-console-consumer \
       --bootstrap-server localhost:9092 \
       --topic radio.playback.events \
       --from-beginning
     ```

#### ✅ Observability

1. **Prometheus Metrics**:
   - Open: http://localhost:8004/metrics
   - Look for metrics like:
     - `http_requests_total`
     - `radio_streaming_*`
     - `kafka_producer_*`

2. **Structured Logging**:
   - Check service logs for JSON-formatted log entries
   - Look for correlation IDs in logs
   - Verify log levels (INFO, ERROR, etc.)

3. **Health Checks**:
   - `/health` - Basic health check
   - `/ready` - Readiness probe (if implemented)

### Success Criteria

Phase 3 is working correctly if:

- ✅ All API endpoints return expected responses
- ✅ Frontend displays radio stations
- ✅ Audio player appears and functions
- ✅ Crossfade transitions work smoothly
- ✅ Playback events are tracked (Kafka/analytics)
- ✅ Metrics are exposed and accessible
- ✅ Logging is structured and includes correlation IDs
- ✅ Database contains test data
- ✅ All services start without errors

---

## Troubleshooting

### Wrong environment detected?

```bash
# Check current environment
echo $ENVIRONMENT

# Set explicitly
export ENVIRONMENT=development
```

### Mock APIs not working?

```bash
# Check feature flag
grep USE_MOCK_APIS .env.development

# Should be: USE_MOCK_APIS=true
```

### Can't seed data?

```bash
# Check environment
echo $ENVIRONMENT

# Check flag
grep SEED_MOCK_DATA .env.development

# Should be: SEED_MOCK_DATA=true
```

### Issue: "No stations found"
**Solution**: Run the seed script:
```bash
python scripts/seed-mock-data.py
```

### Issue: "Cannot connect to database"
**Solution**: 
1. Check PostgreSQL is running: `docker compose -f infrastructure/docker/docker-compose.dev.yml ps postgres`
2. Wait a few seconds for PostgreSQL to initialize
3. Verify connection string in environment variables

### Issue: "Audio doesn't play"
**Solution**:
- Audio files need to be uploaded to MinIO
- Tracks in database need valid `file_path` pointing to MinIO objects
- For testing, you can use mock audio files or test with HTTP range requests

### Issue: "Frontend can't connect to backend"
**Solution**:
1. Check backend is running on port 8004
2. Check CORS settings in `backend/radio-streaming/src/main.py`
3. Verify API URL in `frontend/src/lib/api/client.ts`

### Issue: "Kafka connection errors"
**Solution**:
1. Check Kafka is running: `docker compose -f infrastructure/docker/docker-compose.dev.yml ps kafka`
2. Wait for Kafka to fully start (can take 30+ seconds)
3. Check Kafka logs: `docker compose -f infrastructure/docker/docker-compose.dev.yml logs kafka`

---

## Notes

- For audio playback to work, you need actual MP3 files in MinIO
- The seed script creates database records but doesn't upload audio files
- Crossfade testing requires multiple tracks to be available
- Kafka integration can be verified through analytics service logs

