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

- **[Quick Start](docs/QUICKSTART.md)** - Get up and running locally
- **[Development Guide](docs/DEVELOPMENT.md)** - Environment config, testing, troubleshooting
- **[Deployment Guide](docs/DEPLOYMENT.md)** - k3s/Kubernetes deployment
- **[Project Design](docs/PROJECT_DESIGN.md)** - Architecture and design decisions
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
- **Storage**: MinIO/S3
- **Orchestration**: Kubernetes/k3s
- **Observability**: Prometheus, Grafana, ELK Stack

## License

[Your License Here]
