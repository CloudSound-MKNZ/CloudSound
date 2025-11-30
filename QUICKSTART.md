# Quick Start Guide - Running CloudSound Locally

This guide shows you how to run CloudSound **locally for development** using Docker Compose. You do **NOT** need k3s/Kubernetes for local development.

## Prerequisites

- **Docker** and **Docker Compose** installed
- **Python 3.11+** (for backend services)
- **Node.js 20+** (for frontend)
- **PostgreSQL client tools** (optional, for database access)

## Step 1: Start Infrastructure Services

Start all the infrastructure services (PostgreSQL, Kafka, RabbitMQ, MinIO) using Docker Compose:

```bash
cd /home/tef/Gits/CloudSound
docker-compose -f infrastructure/docker/docker-compose.dev.yml up -d
```

This starts:
- **PostgreSQL** on port 5432
- **Kafka** on port 9092
- **RabbitMQ** on ports 5672 (AMQP) and 15672 (Management UI)
- **MinIO** on ports 9000 (API) and 9001 (Console)

Verify services are running:
```bash
docker compose -f infrastructure/docker/docker-compose.dev.yml ps
# OR: docker-compose -f infrastructure/docker/docker-compose.dev.yml ps
```

## Step 2: Run Database Migrations

Set up the database schema:

```bash
cd backend/shared/db
alembic upgrade head
cd ../../..
```

## Step 3: Seed Mock Data (Optional)

Populate the database with test data:

```bash
python scripts/seed-mock-data.py
```

This creates sample artists, tracks, radio stations, etc.

## Step 4: Start Backend Services

You can run services individually for development. For **User Story 1 (Radio Streaming)**, start:

### Radio Streaming Service

```bash
cd backend/radio-streaming
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8004
```

The service will be available at: http://localhost:8004

### Analytics Service (for playback events)

```bash
cd backend/analytics
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8007
```

## Step 5: Start Frontend

```bash
cd frontend
npm install
npm run dev
```

The frontend will be available at: http://localhost:5173 (or the port Vite assigns)

## Access Points

Once everything is running:

- **Frontend**: http://localhost:5173
- **Radio Streaming API**: http://localhost:8004
  - API Docs: http://localhost:8004/docs
  - Metrics: http://localhost:8004/metrics
- **RabbitMQ Management**: http://localhost:15672 (user: `cloudsound`, pass: `cloudsound_dev`)
- **MinIO Console**: http://localhost:9001 (user: `minioadmin`, pass: `minioadmin`)

## Testing the Radio Streaming Feature

1. Open http://localhost:5173 in your browser
2. Click "View Radio Stations"
3. Click on a station to see details
4. Click "Play" to stream audio

**Note**: For audio to actually play, you need to:
- Have MP3 files uploaded to MinIO, OR
- The tracks in the database need valid file paths

## Troubleshooting

### Services won't start
- Check if ports are already in use: `lsof -i :5432` (or the port in question)
- Check Docker logs: `docker compose -f infrastructure/docker/docker-compose.dev.yml logs`

### Database connection errors
- Wait a few seconds after starting Docker Compose for PostgreSQL to initialize
- Check PostgreSQL is healthy: `docker compose -f infrastructure/docker/docker-compose.dev.yml ps postgres`

### Frontend can't connect to backend
- Make sure the backend service is running on the expected port
- Check the API URL in `frontend/src/lib/api/client.ts` (defaults to `http://localhost:8004/api/v1`)

## Stopping Everything

```bash
# Stop backend services (Ctrl+C in their terminals)
# Stop frontend (Ctrl+C)

# Stop infrastructure
docker compose -f infrastructure/docker/docker-compose.dev.yml down
# OR: docker-compose -f infrastructure/docker/docker-compose.dev.yml down

# To also remove volumes (deletes all data):
docker compose -f infrastructure/docker/docker-compose.dev.yml down -v
```

## What About k3s?

**k3s/Kubernetes is for production deployment**, not local development. The project is designed to:
- **Develop locally** with Docker Compose (what you're doing now)
- **Deploy to k3s/Kubernetes** for production (later, when ready)

The Kubernetes manifests in `infrastructure/kubernetes/` are for production deployment, not required for local development.

