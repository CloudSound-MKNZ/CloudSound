# CloudSound Developer Guide

This guide provides comprehensive instructions for setting up and developing the CloudSound platform.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Development Environment Setup](#development-environment-setup)
- [Repository Structure](#repository-structure)
- [Service Development](#service-development)
- [Working with the Shared Library](#working-with-the-shared-library)
- [API Development](#api-development)
- [Database Operations](#database-operations)
- [Testing](#testing)
- [Code Style & Linting](#code-style--linting)
- [Git Workflow](#git-workflow)
- [Debugging](#debugging)

## Architecture Overview

CloudSound is a microservices-based music streaming platform with the following architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (SvelteKit)                      │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        API Gateway                               │
│        (Authentication, Rate Limiting, Request Routing)          │
└─────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────┬───────────┼───────────┬───────────┐
        ▼           ▼           ▼           ▼           ▼
┌─────────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│    Radio    │ │ Concert │ │  Music  │ │  Event  │ │  Auth   │
│  Streaming  │ │  Mgmt   │ │Discovery│ │ Manager │ │ Service │
└─────────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
        │           │           │           │           │
        └───────────┴───────────┼───────────┴───────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                    Shared Infrastructure                         │
│     PostgreSQL │ Kafka │ RabbitMQ │ MinIO │ Prometheus          │
└─────────────────────────────────────────────────────────────────┘
```

### Services

| Service | Port | Description |
|---------|------|-------------|
| api-gateway | 8000 | Request routing, authentication, rate limiting |
| admin-management | 8001 | Admin user management |
| event-manager | 8002 | Facebook Events integration |
| music-discovery | 8003 | YouTube/Bandcamp music discovery |
| radio-streaming | 8004 | Audio streaming, stations |
| concert-management | 8005 | Concert schedule management |
| authentication | 8006 | JWT token management |
| analytics | 8007 | Playback statistics |

## Development Environment Setup

### Prerequisites

```bash
# Python 3.11+
python3 --version

# Node.js 18+
node --version

# Docker & Docker Compose
docker --version
docker compose version

# Git
git --version
```

### Clone Repositories

```bash
mkdir ~/CloudSound-Workspace && cd ~/CloudSound-Workspace

# Clone all repos
git clone git@github.com:CloudSound-MKNZ/CloudSound.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-shared.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-radio-streaming.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-concert-management.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-authentication.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-analytics.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-admin-management.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-api-gateway.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-event-manager.git
git clone git@github.com:CloudSound-MKNZ/cloudsound-music-discovery.git
```

### Python Environment Setup

```bash
# Create virtual environment for each service
cd ~/CloudSound-Workspace

for service in cloudsound-shared cloudsound-radio-streaming cloudsound-concert-management \
  cloudsound-authentication cloudsound-analytics cloudsound-admin-management \
  cloudsound-api-gateway cloudsound-event-manager cloudsound-music-discovery; do
  cd $service
  python3 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
  deactivate
  cd ..
done

# Install shared library in editable mode
cd cloudsound-shared
source venv/bin/activate
pip install -e .
```

### Start Infrastructure

```bash
cd ~/CloudSound-Workspace/CloudSound/infrastructure/docker

# Start infrastructure services
docker compose -f docker-compose.dev.yml up -d

# Verify services
docker compose -f docker-compose.dev.yml ps
```

### Environment Variables

Create `.env` file in your shell profile or project root:

```bash
# ~/.bashrc or ~/.zshrc
export DATABASE_URL="postgresql://cloudsound:cloudsound_secret@localhost:5432/cloudsound"
export KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
export RABBITMQ_HOST="localhost"
export MINIO_ENDPOINT="localhost:9000"
export JWT_SECRET_KEY="development-secret-key"
export USE_MOCK_APIS="true"
export LOG_LEVEL="DEBUG"
export ENVIRONMENT="development"
```

### IDE Setup (Cursor/VS Code)

Open multi-root workspace:

```bash
cursor ~/CloudSound-Workspace/CloudSound/cloudsound.code-workspace
```

Recommended extensions:
- Python
- Pylance
- Svelte for VS Code
- Docker
- YAML
- GitLens

## Repository Structure

### Main Repository (CloudSound)

```
CloudSound/
├── frontend/                 # SvelteKit frontend
│   ├── src/
│   │   ├── lib/
│   │   │   ├── api/         # API client
│   │   │   ├── components/  # Svelte components
│   │   │   ├── stores/      # State management
│   │   │   └── utils/       # Utilities
│   │   └── routes/          # Page routes
│   └── static/              # Static assets
├── infrastructure/
│   ├── docker/              # Docker Compose files
│   ├── kubernetes/          # K8s manifests
│   └── helm/                # Helm chart
├── specs/                   # Design documents
│   └── 001-cloudsound-platform/
│       ├── plan.md
│       ├── spec.md
│       └── tasks.md
└── docs/                    # Documentation
```

### Service Repository Structure

```
cloudsound-<service>/
├── src/
│   ├── __init__.py
│   ├── main.py              # FastAPI application
│   ├── api/                 # API endpoints
│   │   └── *.py
│   ├── models/              # SQLAlchemy models
│   │   └── *.py
│   ├── services/            # Business logic
│   │   └── *.py
│   ├── consumers/           # Kafka/RabbitMQ consumers
│   │   └── *.py
│   ├── producers/           # Kafka/RabbitMQ producers
│   │   └── *.py
│   └── metrics.py           # Prometheus metrics
├── tests/
│   ├── __init__.py
│   └── test_*.py
├── Dockerfile
├── requirements.txt
└── README.md
```

## Service Development

### Creating a New Endpoint

1. **Define models** in `src/models/`:

```python
# src/models/my_model.py
from sqlalchemy import Column, String, DateTime
from cloudsound_shared.models.base import Base
import uuid

class MyModel(Base):
    __tablename__ = "my_models"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime, server_default=func.now())
```

2. **Create service** in `src/services/`:

```python
# src/services/my_service.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..models.my_model import MyModel

class MyService:
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_all(self) -> list[MyModel]:
        result = await self.db.execute(select(MyModel))
        return result.scalars().all()
    
    async def create(self, name: str) -> MyModel:
        item = MyModel(name=name)
        self.db.add(item)
        await self.db.commit()
        await self.db.refresh(item)
        return item
```

3. **Define API endpoints** in `src/api/`:

```python
# src/api/my_endpoint.py
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from cloudsound_shared.db.pool import get_db
from cloudsound_shared.exceptions import NotFoundError
from ..services.my_service import MyService

router = APIRouter(prefix="/my-resource", tags=["my-resource"])

class MyResourceResponse(BaseModel):
    id: str
    name: str

class CreateMyResourceRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)

@router.get("", response_model=list[MyResourceResponse])
async def list_resources(db: AsyncSession = Depends(get_db)):
    """List all resources."""
    service = MyService(db)
    return await service.get_all()

@router.post("", response_model=MyResourceResponse, status_code=201)
async def create_resource(
    request: CreateMyResourceRequest,
    db: AsyncSession = Depends(get_db),
):
    """Create a new resource."""
    service = MyService(db)
    return await service.create(request.name)
```

4. **Register router** in `src/main.py`:

```python
from .api.my_endpoint import router as my_router

app.include_router(my_router, prefix=app_settings.api_prefix)
```

### Running a Service

```bash
cd ~/CloudSound-Workspace/cloudsound-radio-streaming
source venv/bin/activate
uvicorn src.main:app --reload --port 8004
```

### Adding Metrics

```python
# src/metrics.py
from prometheus_client import Counter, Histogram

MY_REQUESTS = Counter(
    "my_requests_total",
    "Total my resource requests",
    ["method", "status"]
)

MY_LATENCY = Histogram(
    "my_request_duration_seconds",
    "Request latency",
    ["endpoint"]
)

# Use in endpoints
@MY_LATENCY.labels(endpoint="list").time()
async def list_resources(...):
    MY_REQUESTS.labels(method="GET", status="200").inc()
    ...
```

## Working with the Shared Library

### Installing for Development

```bash
cd ~/CloudSound-Workspace/cloudsound-shared
source venv/bin/activate
pip install -e .
```

### Using Shared Components

```python
# Database
from cloudsound_shared.db.pool import get_db, get_async_session
from cloudsound_shared.models.base import Base

# Logging
from cloudsound_shared.logging import configure_logging, get_logger
logger = get_logger(__name__)

# Configuration
from cloudsound_shared.config.settings import app_settings

# Exceptions
from cloudsound_shared.exceptions import (
    NotFoundError,
    ValidationError,
    AuthenticationError,
)

# JWT
from cloudsound_shared.jwt_handler import create_access_token, verify_token

# Error handling
from cloudsound_shared.middleware.error_handler import register_exception_handlers
```

### Adding New Shared Components

1. Add to `cloudsound_shared/` directory
2. Update `__init__.py` exports if needed
3. Bump version in `pyproject.toml`
4. Update services to use new version

## API Development

### Request Validation

Use Pydantic models with field validators:

```python
from pydantic import BaseModel, Field, field_validator
from uuid import UUID

class CreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    email: str = Field(..., pattern=r"^[\w\.-]+@[\w\.-]+\.\w+$")
    
    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        return v.strip()
```

### Custom Exceptions

Use CloudSound exceptions for consistent error responses:

```python
from cloudsound_shared.exceptions import (
    NotFoundError,
    ValidationError,
    AuthorizationError,
    ConflictError,
)

async def get_item(item_id: UUID):
    item = await service.get_by_id(item_id)
    if not item:
        raise NotFoundError(
            message=f"Item {item_id} not found",
            details={"item_id": str(item_id)},
        )
    return item
```

### API Documentation

FastAPI auto-generates OpenAPI documentation:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- OpenAPI JSON: `http://localhost:8000/openapi.json`

## Database Operations

### Creating Migrations

```bash
cd ~/CloudSound-Workspace/cloudsound-shared
source venv/bin/activate

# Auto-generate migration
alembic revision --autogenerate -m "Add my_model table"

# Create empty migration
alembic revision -m "Custom migration"
```

### Running Migrations

```bash
# Apply all migrations
alembic upgrade head

# Apply specific migration
alembic upgrade +1

# Rollback
alembic downgrade -1

# Show current version
alembic current

# Show history
alembic history
```

### Database Access

```python
# Async session (FastAPI dependency)
from cloudsound_shared.db.pool import get_db

@router.get("/items")
async def get_items(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Item))
    return result.scalars().all()

# Direct session usage
from cloudsound_shared.db.pool import get_async_session

async with get_async_session() as session:
    result = await session.execute(select(Item))
    items = result.scalars().all()
```

## Testing

### Running Tests

```bash
cd ~/CloudSound-Workspace/cloudsound-<service>
source venv/bin/activate

# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific test
pytest tests/test_api.py::test_list_items -v
```

### Writing Tests

```python
# tests/test_api.py
import pytest
from httpx import AsyncClient
from src.main import app

@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.mark.asyncio
async def test_list_items(client):
    response = await client.get("/api/v1/items")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

@pytest.mark.asyncio
async def test_create_item(client):
    response = await client.post(
        "/api/v1/items",
        json={"name": "Test Item"}
    )
    assert response.status_code == 201
    assert response.json()["name"] == "Test Item"
```

## Code Style & Linting

### Python (Ruff)

```bash
# Check code
ruff check .

# Fix automatically
ruff check --fix .

# Format code
ruff format .
```

### Configuration

```toml
# pyproject.toml
[tool.ruff]
line-length = 100
select = ["E", "F", "I", "UP", "B"]
ignore = ["E501"]

[tool.ruff.isort]
known-first-party = ["src", "cloudsound_shared"]
```

### Frontend (ESLint/Prettier)

```bash
cd ~/CloudSound-Workspace/CloudSound/frontend

# Lint
npm run lint

# Format
npm run format
```

## Git Workflow

### Branch Naming

- `feature/<description>` - New features
- `fix/<description>` - Bug fixes
- `refactor/<description>` - Code refactoring
- `docs/<description>` - Documentation

### Commit Messages

Follow conventional commits:

```
feat(radio): add crossfade functionality
fix(concerts): resolve date parsing issue
docs(readme): update installation instructions
refactor(auth): simplify token validation
```

### Pull Request Process

1. Create feature branch
2. Make changes
3. Run tests and linting
4. Update tasks.md if applicable
5. Create PR with description
6. Request review
7. Merge after approval

## Debugging

### Local Debugging

VS Code launch configuration:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Radio Streaming",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": ["src.main:app", "--reload", "--port", "8004"],
      "cwd": "${workspaceFolder}/../cloudsound-radio-streaming",
      "envFile": "${workspaceFolder}/.env"
    }
  ]
}
```

### Logging

```python
from cloudsound_shared.logging import get_logger

logger = get_logger(__name__)

# Structured logging
logger.info("processing_request", user_id=user_id, action="create")
logger.error("operation_failed", error=str(exc), exc_info=True)
```

### Debugging Kafka

```bash
# List topics
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list

# Consume messages
docker exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic radio.playback.events \
  --from-beginning
```

### Debugging PostgreSQL

```bash
# Connect to database
docker exec -it postgres psql -U cloudsound -d cloudsound

# Common queries
\dt                          -- List tables
\d+ my_table                 -- Describe table
SELECT * FROM my_table LIMIT 10;
```

## Common Issues & Solutions

### Import Errors

```bash
# Ensure shared library is installed
pip install -e ~/CloudSound-Workspace/cloudsound-shared
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Verify connection string
echo $DATABASE_URL
```

### Kafka Connection Issues

```bash
# Check Kafka is running
docker ps | grep kafka

# Verify broker is accessible
docker exec kafka kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

## Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy Documentation](https://docs.sqlalchemy.org/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [SvelteKit Documentation](https://kit.svelte.dev/)
- [Project Specifications](../specs/001-cloudsound-platform/)

