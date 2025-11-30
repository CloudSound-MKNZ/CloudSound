# Implementation Plan: CloudSound Radio Platform

**Branch**: `001-cloudsound-platform` | **Date**: 2025-11-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-cloudsound-platform/spec.md`

## Summary

Build a cloud-native microservices radio platform that enables local music clubs to manage concert schedules and stream music. The system automatically discovers music from YouTube and Bandcamp APIs, integrates with Facebook Events API, and provides a SvelteKit frontend for users and administrators. The architecture uses Kafka for event streaming, RabbitMQ for task queues, and implements comprehensive observability with Prometheus, ELK Stack, and Grafana.

## Technical Context

**Language/Version**: Python 3.11+  
**Primary Dependencies**: FastAPI, SQLAlchemy, Pydantic, Kafka-Python, pika (RabbitMQ), asyncpg, aiohttp  
**Storage**: PostgreSQL 15+ (relational data), MinIO/S3 (MP3 files)  
**Testing**: pytest, pytest-asyncio, httpx (for testing async endpoints)  
**Target Platform**: Kubernetes (k3s) on cloud provider (AWS/Azure/GCP)  
**Project Type**: Web application (microservices architecture)  
**Performance Goals**: 
- Support 50+ concurrent radio listeners per instance
- API response time p95 < 500ms
- Music download completion within 5 minutes for typical tracks
- Page load time < 2 seconds for concert schedule

**Constraints**: 
- Must use microservices architecture (course requirement)
- Must implement Event Sourcing & CQRS with Kafka (5 points)
- Must use Kubernetes for orchestration (6 points)
- Must implement observability (metrics, logging, health checks)
- Must be deployable to cloud (5 points)

**Scale/Scope**: 
- 10,000+ concerts in database
- 100,000+ music tracks
- 1TB+ storage for MP3 files
- 50+ concurrent users per service instance

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Compliance Verification

✅ **Microservices Architecture**: All services are independent with clear boundaries  
✅ **Event-Driven Communication**: Kafka for events, RabbitMQ for tasks  
✅ **Observability First**: Prometheus metrics, ELK logging, health checks defined  
✅ **API-First Design**: OpenAPI/Swagger contracts will be defined  
✅ **Cloud-Native Principles**: Docker containers, Kubernetes manifests, Helm charts  
✅ **Security by Default**: JWT authentication, HTTPS/TLS, input validation  
✅ **Fault Tolerance**: Circuit breakers, retries, graceful degradation  

**GATE STATUS**: ✅ PASSED - Architecture aligns with constitution principles

## Project Structure

### Documentation (this feature)

```text
specs/001-cloudsound-platform/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output (technical research)
├── data-model.md        # Phase 1 output (database schema)
├── quickstart.md        # Phase 1 output (test scenarios)
├── contracts/           # Phase 1 output (API contracts)
│   ├── openapi.yaml    # OpenAPI specification
│   └── grpc/           # gRPC proto files
└── tasks.md             # Phase 2 output (task breakdown)
```

### Source Code (repository root)

```text
frontend/
├── src/
│   ├── routes/         # SvelteKit routes
│   ├── lib/            # Shared components and utilities
│   ├── stores/         # State management
│   └── app.html        # Main HTML template
├── static/             # Static assets
├── package.json
└── Dockerfile

backend/
├── api-gateway/
│   ├── src/
│   │   ├── main.py
│   │   ├── routes/
│   │   └── middleware/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── concert-management/
│   ├── src/
│   │   ├── main.py
│   │   ├── models/
│   │   ├── services/
│   │   └── api/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── event-manager/
│   ├── src/
│   │   ├── main.py
│   │   ├── facebook_client.py
│   │   ├── kafka_producer.py
│   │   └── parsers/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── music-discovery/
│   ├── src/
│   │   ├── main.py
│   │   ├── youtube_client.py
│   │   ├── bandcamp_client.py
│   │   ├── downloader.py
│   │   └── kafka_consumer.py
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── radio-streaming/
│   ├── src/
│   │   ├── main.py
│   │   ├── streaming/
│   │   ├── stations/
│   │   └── kafka_consumer.py
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── admin-management/
│   ├── src/
│   │   ├── main.py
│   │   ├── models/
│   │   └── api/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── authentication/
│   ├── src/
│   │   ├── main.py
│   │   ├── jwt_handler.py
│   │   └── api/
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
└── analytics/          # Optional service
    ├── src/
    ├── tests/
    ├── Dockerfile
    └── requirements.txt

infrastructure/
├── kubernetes/
│   ├── frontend/
│   ├── api-gateway/
│   ├── concert-management/
│   ├── event-manager/
│   ├── music-discovery/
│   ├── radio-streaming/
│   ├── admin-management/
│   ├── authentication/
│   ├── postgresql/
│   ├── kafka/
│   ├── rabbitmq/
│   ├── prometheus/
│   ├── grafana/
│   └── elk/
├── helm/
│   └── cloudsound/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── docker/
    └── docker-compose.yml  # For local development

scripts/
├── setup-dev.sh
├── deploy.sh
└── test-all.sh
```

**Structure Decision**: Microservices architecture with separate repositories/directories for each service. Frontend is a standalone service. Infrastructure code is centralized for easier management.

## Complexity Tracking

> **No violations identified** - Architecture follows best practices and course requirements.

## Phase 0: Research & Technical Decisions

### Research Areas

1. **FastAPI Best Practices**
   - Async/await patterns
   - Dependency injection
   - Background tasks
   - WebSocket support (if needed for real-time updates)

2. **Kafka Integration**
   - Python Kafka client (kafka-python vs confluent-kafka)
   - Topic design and partitioning strategy
   - Consumer group configuration
   - Error handling and retry logic

3. **RabbitMQ Integration**
   - Python client (pika vs aio-pika for async)
   - Queue design and routing
   - Message acknowledgment patterns
   - Dead letter queues

4. **Audio Streaming**
   - HTTP range requests for audio streaming
   - Crossfade implementation (client-side vs server-side)
   - Audio format compatibility (MP3, OGG, etc.)
   - Streaming protocols (HLS, DASH, or simple HTTP)

5. **YouTube/Bandcamp API Integration**
   - API rate limits and quotas
   - Authentication methods
   - Music extraction/download methods
   - Legal considerations for music storage

6. **Facebook Events API**
   - Authentication and permissions
   - Rate limits
   - Event data structure
   - Webhook vs polling strategy

7. **SvelteKit Deployment**
   - Static export vs SSR
   - API route handling
   - Environment variables
   - Build optimization

8. **Kubernetes Deployment**
   - Resource requests and limits
   - Health check configuration
   - Service mesh (Istio) vs API Gateway (Kong)
   - Ingress controller setup

9. **Observability Stack**
   - Prometheus metrics format
   - ELK Stack vs Loki for logging
   - Grafana dashboard creation
   - Alerting rules

10. **Database Design**
    - PostgreSQL schema for concerts, artists, tracks
    - Indexing strategy
    - Connection pooling
    - Migration management (Alembic)

**Output**: `research.md` with decisions, rationale, and alternatives considered

## Phase 1: Design & Contracts

### Data Model

**Entities**:
- **Concert**: id, date, location, performers (JSON array), facebook_event_id, created_at, updated_at
- **Artist**: id, name, genre, created_at
- **Track**: id, title, artist_id, duration_seconds, file_path (MinIO/S3), file_size, created_at
- **RadioStation**: id, name, type (upcoming/past/genre), genre (nullable), created_at
- **StationTrack**: id, station_id, track_id, order, created_at (many-to-many with ordering)
- **AdminUser**: id, username, email, password_hash, created_at, last_login
- **PlaybackEvent**: id, station_id, track_id, timestamp, duration_seconds (for statistics)

**Relationships**:
- Concert → Artist (many-to-many via junction table)
- Artist → Track (one-to-many)
- RadioStation → Track (many-to-many via StationTrack)
- AdminUser (standalone)

**Output**: `data-model.md` with complete schema, indexes, and relationships

### API Contracts

#### REST APIs (OpenAPI/Swagger)

1. **Frontend Service** (SvelteKit)
   - Serves static files
   - API routes proxy to backend via API Gateway

2. **API Gateway**
   - `/api/v1/concerts` - GET (list), POST (create - admin only)
   - `/api/v1/concerts/{id}` - GET, PUT (admin), DELETE (admin)
   - `/api/v1/radio/stations` - GET (list stations)
   - `/api/v1/radio/stations/{id}/stream` - GET (stream audio)
   - `/api/v1/search` - GET (search music)
   - `/api/v1/auth/login` - POST
   - `/api/v1/auth/refresh` - POST
   - `/api/v1/admin/stats` - GET (admin only)

3. **Concert Management Service**
   - Internal API for concert CRUD operations
   - Kafka consumer for event updates

4. **Event Manager Service**
   - Kafka producer for Facebook events
   - Scheduled job for Facebook API polling

5. **Music Discovery Service**
   - Kafka consumer for event processing
   - RabbitMQ producer for download tasks
   - Internal API for download status

6. **Radio Streaming Service**
   - Kafka consumer for music updates
   - Streaming endpoint (HTTP range requests)
   - Internal API for station management

7. **Admin Management Service**
   - Admin CRUD operations
   - Statistics aggregation

8. **Authentication Service**
   - JWT token generation/validation
   - User session management

#### gRPC Services

- **Concert Management** ↔ **Event Manager**: Event synchronization
- **Music Discovery** ↔ **Radio Streaming**: Music metadata updates
- **All Services** ↔ **Analytics**: Playback event streaming

**Output**: `contracts/openapi.yaml` and `contracts/grpc/*.proto` files

### Quickstart Scenarios

1. **Local Development Setup**
   - Docker Compose for infrastructure (Kafka, RabbitMQ, PostgreSQL)
   - Local service development
   - Testing with mock external APIs

2. **End-to-End Test Scenario**
   - Admin creates concert
   - Facebook event is linked
   - Music is discovered and downloaded
   - Radio station is updated
   - User streams music

3. **Kubernetes Deployment**
   - Helm chart installation
   - Service verification
   - Health check validation

**Output**: `quickstart.md` with step-by-step scenarios

## Phase 2: Implementation Planning

### Service Implementation Order

1. **Infrastructure Setup** (Foundation)
   - PostgreSQL database
   - Kafka cluster
   - RabbitMQ cluster
   - MinIO/S3 setup
   - Kubernetes cluster preparation

2. **Core Services** (MVP)
   - Authentication Service
   - Concert Management Service
   - Frontend Service (basic UI)

3. **Integration Services**
   - API Gateway
   - Event Manager Service
   - Music Discovery Service

4. **Streaming Services**
   - Radio Streaming Service
   - Admin Management Service

5. **Observability**
   - Prometheus setup
   - ELK Stack setup
   - Grafana dashboards

6. **Advanced Features**
   - Analytics Service
   - Advanced search
   - Performance optimization

### Technology Decisions

- **FastAPI**: Modern, fast, async Python framework
- **SQLAlchemy**: ORM for database operations
- **Alembic**: Database migrations
- **Pydantic**: Data validation
- **kafka-python**: Kafka client (or confluent-kafka if performance needed)
- **pika**: RabbitMQ client (or aio-pika for async)
- **asyncpg**: Async PostgreSQL driver
- **aiohttp**: Async HTTP client for external APIs
- **prometheus-client**: Metrics export
- **structlog**: Structured logging

### Deployment Strategy

1. **Development**: Docker Compose for local development
2. **Staging**: Kubernetes cluster with Helm charts
3. **Production**: Cloud Kubernetes (AWS EKS, Azure AKS, or GCP GKE)

### Testing Strategy

- **Unit Tests**: Business logic, utilities
- **Integration Tests**: API endpoints, database operations
- **Contract Tests**: Inter-service communication
- **End-to-End Tests**: Complete user flows
- **Load Tests**: Performance and scalability

## Next Steps

1. Complete Phase 0 research and document decisions
2. Create data model and API contracts (Phase 1)
3. Generate task breakdown (Phase 2)
4. Begin implementation following task order

