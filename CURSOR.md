# CloudSound Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-30

## Active Technologies

- Python 3.11+ + FastAPI (Backend services)
- SvelteKit (Frontend service)
- PostgreSQL 15+ (Database)
- Apache Kafka (Event streaming)
- RabbitMQ (Task queues)
- Prometheus (Metrics)
- ELK Stack / Loki (Logging)
- Grafana (Visualization)
- Docker (Containerization)
- Kubernetes / k3s (Orchestration)
- MinIO / S3 (Object storage for MP3 files)
- Kong / Istio (API Gateway)

## Project Structure

```text
.
├── frontend/                    # SvelteKit frontend service
│   ├── src/
│   ├── static/
│   └── package.json
├── backend/
│   ├── api-gateway/            # API Gateway service
│   ├── concert-management/     # Concert Management Service
│   ├── event-manager/           # Event Manager Service (Facebook API)
│   ├── music-discovery/        # Music Discovery Service
│   ├── radio-streaming/         # Radio Streaming Service
│   ├── admin-management/       # Admin Management Service
│   ├── authentication/         # Authentication Service
│   └── analytics/              # Analytics Service (optional)
├── infrastructure/
│   ├── kubernetes/             # Kubernetes manifests
│   ├── helm/                   # Helm charts
│   ├── docker/                 # Dockerfiles
│   └── terraform/              # Infrastructure as code (optional)
├── memory/
│   └── constitution.md         # Project principles
├── specs/                      # Feature specifications
│   └── 001-cloudsound-platform/
│       ├── spec.md
│       ├── plan.md
│       └── tasks.md
└── scripts/                    # Helper scripts
```

## Commands

### Backend (Python/FastAPI)
```bash
# Development
cd backend/<service>
uvicorn main:app --reload --port 8000

# Testing
pytest
ruff check .
black --check .

# Build Docker image
docker build -t cloudsound-<service>:latest .
```

### Frontend (SvelteKit)
```bash
# Development
cd frontend
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

### Infrastructure
```bash
# Deploy with Helm
helm install cloudsound ./helm/cloudsound

# Apply Kubernetes manifests
kubectl apply -f infrastructure/kubernetes/

# Check service health
kubectl get pods
kubectl logs -f <pod-name>
```

## Code Style

### Python
- Follow PEP 8 style guide
- Use type hints for all function signatures
- Format code with Black
- Lint with Ruff
- Maximum line length: 100 characters
- Use async/await for I/O operations

### Svelte
- Use TypeScript for type safety
- Follow SvelteKit conventions
- Component-based architecture
- Use stores for state management

## Recent Changes

- 2025-11-30: Initialized spec-kit integration and created comprehensive project specification
- 2025-11-30: Defined microservices architecture with Kafka event streaming and RabbitMQ task queues
- 2025-11-30: Established observability stack (Prometheus, ELK, Grafana)

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
