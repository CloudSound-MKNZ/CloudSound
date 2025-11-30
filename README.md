# CloudSound Radio Platform

A cloud-native microservices radio streaming platform for local music clubs, enabling concert schedule management and music streaming with automatic music discovery.

## Quick Start

### Development Environment

```bash
# 1. Setup development environment (creates .env, starts Docker services, seeds data)
./scripts/setup-dev.sh

# 2. Start a backend service
cd backend/authentication
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8006

# 3. Start frontend (requires Node.js 20+)
cd frontend
npm install
npm run dev
```

## Environment Configuration

**Important**: CloudSound uses environment-based configuration, NOT Git branches.

- **Development**: Mock APIs enabled, mock data seeded
- **Test**: Mock APIs enabled, isolated test database
- **Production**: Real APIs required, no mock data

See [docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md) for detailed configuration guide.

## Project Structure

```
.
├── frontend/              # SvelteKit frontend service
├── backend/               # Microservices
│   ├── api-gateway/
│   ├── authentication/
│   ├── concert-management/
│   ├── event-manager/
│   ├── music-discovery/
│   ├── radio-streaming/
│   ├── admin-management/
│   └── shared/           # Shared utilities
├── infrastructure/       # Infrastructure as code
│   ├── docker/          # Docker Compose files
│   ├── kubernetes/       # K8s manifests
│   └── helm/            # Helm charts
├── scripts/              # Helper scripts
└── specs/               # Spec-Driven Development artifacts
```

## Technology Stack

- **Backend**: Python 3.11+ + FastAPI
- **Frontend**: SvelteKit
- **Database**: PostgreSQL 15+
- **Message Brokers**: Apache Kafka, RabbitMQ
- **Storage**: MinIO/S3
- **Observability**: Prometheus, Grafana, ELK Stack
- **Orchestration**: Kubernetes/k3s
- **Containerization**: Docker

## Development Workflow

1. **Setup**: Run `./scripts/setup-dev.sh` to initialize development environment
2. **Code**: Make changes following the [Constitution](memory/constitution.md)
3. **Test**: Run tests with `pytest`
4. **Commit**: Follow conventional commits
5. **Deploy**: Use CI/CD pipelines for test/production

## Mock Data & APIs

Mock data and API clients are automatically enabled in development and test environments:

- **Mock APIs**: YouTube, Bandcamp, Facebook Events
- **Mock Data**: Artists, tracks, radio stations, concerts
- **Seeding**: Automatic in dev/test, blocked in production

See [scripts/README.md](scripts/README.md) for details.

## Documentation

- [Environment Configuration](docs/ENVIRONMENTS.md)
- [Project Design](project_design.md)
- [Constitution](memory/constitution.md)
- [Spec-Driven Development](specs/001-cloudsound-platform/)

## License

[Your License Here]
