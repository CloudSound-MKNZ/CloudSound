# CloudSound Radio Platform

A cloud-native microservices radio streaming platform for local music clubs, enabling concert schedule management and music streaming with automatic music discovery.

## Quick Start

```bash
# Start everything with Docker Compose (default for development)
./scripts/start.sh

# Stop everything
./scripts/stop.sh
```

**Note**: The `start.sh` script uses **Docker Compose** by default for local development. It does NOT automatically deploy k3s/Kubernetes. For k3s deployment, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

For more details, see [scripts/README.md](scripts/README.md) or [docs/QUICKSTART.md](docs/QUICKSTART.md).

## Project Status & Tasks

**Single Source of Truth**: [`specs/001-cloudsound-platform/tasks.md`](specs/001-cloudsound-platform/tasks.md)

All tasks, progress tracking, and implementation status are tracked in the `specs/` folder using Spec-Driven Development (Specify).

> **Note**: For active work tracking, you can use `/speckit.taskstoissues` to convert tasks to GitHub Issues, or use GitHub Issues/Projects directly.

## Documentation

### Getting Started
- **[Quick Start](docs/QUICKSTART.md)** - Get up and running locally
- **[Development Guide](docs/DEVELOPMENT.md)** - Environment config, testing, troubleshooting

### Azure Deployment ☁️
- **[Azure Deployment Guide](docs/AZURE_DEPLOYMENT.md)** ⭐ - Complete Azure deployment guide
- **[Azure Quick Start](docs/QUICKSTART_AZURE.md)** 🚀 - Deploy to Azure in 30 minutes
- **[Azure Functions](docs/AZURE_FUNCTIONS.md)** - Serverless functions deployment
- **[Azure Monitoring](docs/AZURE_MONITORING.md)** - Monitoring & observability setup
- **[Setup Summary](AZURE_SETUP_SUMMARY.md)** - What's been added for Azure

### Kubernetes Deployment
- **[k3s Deployment Guide](docs/DEPLOYMENT.md)** - Local k3s/Kubernetes deployment

### Architecture & Design
- **[Project Design](docs/PROJECT_DESIGN.md)** - Architecture and design decisions
- **[Event Sourcing & CQRS](docs/EVENT_SOURCING_CQRS.md)** - Event-driven architecture
- **[gRPC Implementation](docs/GRPC_IMPLEMENTATION.md)** - Real-time playback events
- **[Serverless Function](docs/SERVERLESS_FUNCTION.md)** - Metadata extraction function

### Development
- **[Cursor IDE Setup](docs/CURSOR.md)** - Development guidelines and commands
- **[Specifications](specs/001-cloudsound-platform/)** - Feature specs, plans, and tasks
- **[Constitution](memory/constitution.md)** - Project principles and standards

## Project Structure

```
.
├── frontend/              # SvelteKit frontend
├── backend/               # Microservices
│   ├── radio-streaming/
│   ├── concert-management/
│   ├── analytics/
│   └── shared/           # Shared utilities
├── azure-functions/       # Serverless functions (metadata extraction)
├── infrastructure/        # Docker, Kubernetes, Helm
├── scripts/               # Helper scripts
├── specs/                 # Spec-Driven Development (tasks & progress)
└── docs/                  # Documentation
```

## Technology Stack

- **Backend**: Python 3.11+ + FastAPI
- **Frontend**: SvelteKit + TypeScript
- **Database**: PostgreSQL 15+
- **Message Brokers**: Apache Kafka, RabbitMQ
- **Storage**: MinIO/Azure Blob Storage
- **Cloud**: Microsoft Azure (AKS, ACR, PostgreSQL, Storage)
- **Infrastructure**: Terraform, Helm, Kubernetes
- **CI/CD**: GitHub Actions
- **Orchestration**: Azure Kubernetes Service (AKS) / k3s
- **Observability**: Prometheus, Grafana, Loki, Azure Monitor, Application Insights

## License

[Your License Here]
