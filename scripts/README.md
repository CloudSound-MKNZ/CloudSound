# Development Scripts

## Quick Start

### 🚀 Start Everything (Docker Compose - Default)
```bash
./scripts/start.sh
```
Starts infrastructure using **Docker Compose** (PostgreSQL, Kafka, RabbitMQ, MinIO), runs database migrations, seeds mock data, and optionally starts all services.

**This is the default for local development.** No k3s/Kubernetes needed!

**Options:**
- `--no-services` - Skip starting backend/frontend services (just setup infrastructure and database)
- `--no-infra` - Skip starting infrastructure (assumes it's already running)
- `--no-seed` - Skip seeding mock data
- `--k3s` - Use k3s instead of Docker Compose (requires k3s already installed and running)

**Examples:**
```bash
# Full startup with Docker Compose (default - recommended for dev)
./scripts/start.sh

# Just setup infrastructure and database, don't start services
./scripts/start.sh --no-services

# Skip infrastructure (already running), just run migrations
./scripts/start.sh --no-infra

# Use k3s instead of Docker Compose (for production-like testing)
# Note: k3s must be installed and running first
./scripts/start.sh --k3s
```

### 📦 Docker Compose vs k3s

- **Docker Compose (default)**: For local development. Automatically starts all infrastructure services.
- **k3s**: For production deployment or production-like testing. **k3s is NOT automatically installed or deployed** - you must install and configure it separately. See [DEPLOYMENT.md](../docs/DEPLOYMENT.md) for k3s setup.

### 🛑 Stop Everything
```bash
./scripts/stop.sh
```
Stops all running services (backend and frontend). Infrastructure (Docker/k3s) keeps running by default.

**Options:**
- `--infra` - Also stop infrastructure (Docker Compose/k3s)

**Examples:**
```bash
# Stop services only (default)
./scripts/stop.sh

# Stop everything including infrastructure
./scripts/stop.sh --infra
```

## What the Scripts Do

### `start.sh`
1. **Infrastructure**: 
   - **Default**: Starts Docker Compose services (PostgreSQL, Kafka, RabbitMQ, MinIO)
   - **With --k3s**: Detects k3s cluster (but does NOT deploy it - you must deploy separately)
2. **Database**: Creates migration venv, runs Alembic migrations
3. **Data**: Seeds mock data (artists, tracks, radio stations, concerts)
4. **Services** (optional): Starts backend services and frontend in background

### `stop.sh`
1. **Services**: Stops all backend services (radio-streaming, analytics) and frontend
2. **Infrastructure** (optional): Stops Docker Compose services if `--infra` flag is used
   - Note: k3s deployments must be stopped manually with `kubectl`

## Manual Service Startup

If you prefer to start services manually in separate terminals:

```bash
# Radio Streaming Service
cd backend/radio-streaming
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8004

# Analytics Service
cd backend/analytics
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8007

# Frontend
cd frontend
npm install
npm run dev
```

## Data Seeding

### Seed Mock Data
```bash
# Make sure PostgreSQL is running (via docker-compose)
python scripts/seed-mock-data.py
```

This creates:
- 1 admin user (admin@cloudsound.local / admin123)
- 8 artists across different genres
- 10 tracks
- 5 radio stations
- 1 upcoming concert

### Seed Concerts
```bash
python scripts/seed-concerts.py
```

## Access Points

Once everything is running:

- **Frontend**: http://localhost:5173
- **Radio Stations**: http://localhost:5173/radio
- **Radio API**: http://localhost:8004
- **Radio API Docs**: http://localhost:8004/docs
- **Analytics API**: http://localhost:8007
- **Analytics Docs**: http://localhost:8007/docs

## Logs

Service logs are written to:
- `/tmp/cloudsound-radio-streaming.log`
- `/tmp/cloudsound-analytics.log`
- `/tmp/cloudsound-frontend.log`

## Azure Scripts

### 💰 Pause/Resume Azure Resources (Save Credits!)

When you're not actively using Azure resources, you can pause them to save credits:

```bash
# Stop AKS and PostgreSQL (save ~$45-60/month)
./scripts/azure-pause-resources.sh stop

# Start everything back up
./scripts/azure-pause-resources.sh start

# Check current status
./scripts/azure-pause-resources.sh status
```

**What gets stopped:**
- ✅ AKS Cluster (~$30-40/month savings)
- ✅ PostgreSQL Flexible Server (~$15-20/month savings)

**What keeps running (minimal cost):**
- Event Hubs (~$10-20/month)
- Storage (~$1-2/month)
- ACR (~$5/month)
- Log Analytics (~$5-15/month)

**Total savings when stopped: ~$45-60/month**

### 📊 Check Azure Costs

```bash
./scripts/check-azure-costs.sh
```

Shows current month costs, resource breakdown, and cost optimization tips.

## Helper Scripts

The `bash/` and `powershell/` directories contain scripts used by the `.specify` system for spec-driven development. These should not be modified manually.
