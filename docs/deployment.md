# CloudSound Deployment Guide

This guide covers deployment strategies for the CloudSound platform, from local development to production Kubernetes environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Docker Compose Deployment](#docker-compose-deployment)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Helm Chart Installation](#helm-chart-installation)
- [Environment Configuration](#environment-configuration)
- [Database Migrations](#database-migrations)
- [Monitoring & Observability](#monitoring--observability)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 24.0+ | Container runtime |
| Docker Compose | 2.20+ | Local orchestration |
| kubectl | 1.28+ | Kubernetes CLI |
| Helm | 3.12+ | Kubernetes package manager |
| Python | 3.11+ | Backend services |
| Node.js | 18+ | Frontend build |

### Infrastructure Requirements

| Component | Development | Staging | Production |
|-----------|-------------|---------|------------|
| PostgreSQL | 1 instance | 1 instance | HA cluster |
| Kafka | 1 broker | 3 brokers | 3+ brokers |
| RabbitMQ | 1 node | 1 node | HA cluster |
| MinIO | 1 instance | 1 instance | Distributed |

## Local Development

### Quick Start

```bash
# Clone all repositories
mkdir ~/CloudSound-Workspace && cd ~/CloudSound-Workspace
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

# Start infrastructure
cd CloudSound
docker compose -f infrastructure/docker/docker-compose.dev.yml up -d

# Run database migrations
cd ../cloudsound-shared
pip install -e .
alembic upgrade head

# Start services (in separate terminals or use docker-compose.services.yml)
```

### Using VS Code / Cursor

Open the workspace file for multi-root workspace support:

```bash
cursor CloudSound/cloudsound.code-workspace
```

## Docker Compose Deployment

### Development Environment

```bash
cd CloudSound/infrastructure/docker

# Start all infrastructure
docker compose -f docker-compose.dev.yml up -d

# Check status
docker compose -f docker-compose.dev.yml ps

# View logs
docker compose -f docker-compose.dev.yml logs -f
```

### Services Configuration

The development compose file starts:
- PostgreSQL (port 5432)
- Kafka (port 9092)
- RabbitMQ (port 5672, management on 15672)
- MinIO (port 9000, console on 9001)
- Prometheus (port 9090)
- Grafana (port 3000)

### Environment Variables

Create `.env` file in the infrastructure/docker directory:

```bash
# Database
POSTGRES_USER=cloudsound
POSTGRES_PASSWORD=cloudsound_secret
POSTGRES_DB=cloudsound

# JWT
JWT_SECRET_KEY=your-super-secret-key-change-in-production
JWT_ALGORITHM=HS256
JWT_EXPIRATION_MINUTES=60

# Kafka
KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# RabbitMQ
RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USER=guest
RABBITMQ_PASSWORD=guest

# MinIO
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=cloudsound-music

# External APIs (placeholders)
USE_MOCK_APIS=true
YOUTUBE_API_KEY=
FACEBOOK_ACCESS_TOKEN=
```

## Kubernetes Deployment

### Cluster Setup (k3s)

```bash
# Install k3s (single node for testing)
curl -sfL https://get.k3s.io | sh -

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### Namespace Setup

```bash
# Create namespace
kubectl create namespace cloudsound

# Set default namespace
kubectl config set-context --current --namespace=cloudsound
```

### Manual Deployment

```bash
cd CloudSound/infrastructure/kubernetes

# Apply infrastructure
kubectl apply -f prometheus/
kubectl apply -f grafana/
kubectl apply -f loki/

# Apply services
kubectl apply -f api-gateway/
kubectl apply -f radio-streaming/
kubectl apply -f concert-management/
kubectl apply -f authentication/
kubectl apply -f analytics/
kubectl apply -f admin-management/
kubectl apply -f event-manager/
kubectl apply -f music-discovery/
```

## Helm Chart Installation

### Add Dependencies

```bash
cd CloudSound/infrastructure/helm/cloudsound

# Update dependencies
helm dependency update
```

### Install Chart

```bash
# Development installation
helm install cloudsound . \
  --namespace cloudsound \
  --create-namespace \
  -f values.yaml

# Production installation
helm install cloudsound . \
  --namespace cloudsound \
  --create-namespace \
  -f values.yaml \
  -f values-production.yaml

# Check deployment
helm status cloudsound -n cloudsound
kubectl get pods -n cloudsound
```

### Upgrade Chart

```bash
# Upgrade with new values
helm upgrade cloudsound . \
  --namespace cloudsound \
  -f values.yaml

# Rollback if needed
helm rollback cloudsound 1 -n cloudsound
```

### Uninstall

```bash
helm uninstall cloudsound -n cloudsound
kubectl delete namespace cloudsound
```

## Environment Configuration

### Configuration Hierarchy

1. Default values in `values.yaml`
2. Environment-specific overrides (`values-production.yaml`)
3. Command-line overrides (`--set`)

### Key Configuration Options

```yaml
# values.yaml structure
global:
  environment: development
  image:
    tag: latest
    pullPolicy: Always

services:
  apiGateway:
    replicas: 2
    resources:
      limits:
        memory: 512Mi
        cpu: 500m

postgresql:
  enabled: true
  auth:
    postgresPassword: ""  # Set via secrets

kafka:
  enabled: true
  replicaCount: 3
```

### Secrets Management

```bash
# Create secrets
kubectl create secret generic cloudsound-secrets \
  --from-literal=postgres-password=your-password \
  --from-literal=jwt-secret=your-jwt-secret \
  --from-literal=minio-secret-key=your-minio-key \
  -n cloudsound
```

## Database Migrations

### Running Migrations

```bash
# In cloudsound-shared directory
cd cloudsound-shared

# Create new migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1

# Show current version
alembic current
```

### Kubernetes Migration Job

The Helm chart includes a pre-install/pre-upgrade hook for migrations:

```yaml
# Applied automatically during helm install/upgrade
kind: Job
metadata:
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
```

## Monitoring & Observability

### Prometheus

Access Prometheus UI:
- Local: http://localhost:9090
- Kubernetes: Port-forward `kubectl port-forward svc/prometheus 9090:9090`

### Grafana

Access Grafana dashboards:
- Local: http://localhost:3000
- Default credentials: admin/admin

Pre-configured dashboards:
- CloudSound Overview
- API Gateway Metrics
- Radio Streaming Metrics
- Music Discovery Metrics

### Loki (Logs)

Query logs in Grafana using LogQL:
```logql
{namespace="cloudsound"} |= "error"
{app="api-gateway"} | json | status_code >= 500
```

### Alerts

Alerts are configured in `prometheus/alerts.yaml`:
- High error rate
- Service down
- Database connection failures
- Kafka consumer lag
- Storage quota warnings

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n cloudsound

# View pod logs
kubectl logs <pod-name> -n cloudsound

# Describe pod for events
kubectl describe pod <pod-name> -n cloudsound
```

#### Database Connection Issues

```bash
# Check database pod
kubectl get pods -l app=postgresql -n cloudsound

# Test connection
kubectl run -it --rm psql --image=postgres:15 \
  --restart=Never -- psql -h postgresql -U cloudsound
```

#### Kafka Consumer Lag

```bash
# Check consumer groups
kubectl exec -it kafka-0 -- \
  kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list

# Describe consumer group
kubectl exec -it kafka-0 -- \
  kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group <group-name>
```

### Health Checks

All services expose health endpoints:
- `/health` - Basic health check
- `/health/ready` - Readiness check (includes dependencies)
- `/metrics` - Prometheus metrics

```bash
# Check service health
curl http://localhost:8000/health

# Check all services
for port in 8000 8001 8002 8003 8004 8005 8006 8007; do
  echo "Port $port: $(curl -s http://localhost:$port/health)"
done
```

### Log Analysis

```bash
# View all service logs
kubectl logs -l app.kubernetes.io/part-of=cloudsound -n cloudsound --tail=100

# Follow logs
kubectl logs -f deployment/api-gateway -n cloudsound

# Search for errors
kubectl logs deployment/api-gateway -n cloudsound | grep -i error
```

## Security Considerations

### Production Checklist

- [ ] Change all default passwords
- [ ] Configure proper CORS origins
- [ ] Enable TLS/HTTPS
- [ ] Set up network policies
- [ ] Configure pod security policies
- [ ] Review and restrict RBAC
- [ ] Enable audit logging
- [ ] Set resource limits on all pods
- [ ] Configure backup strategy for PostgreSQL and MinIO

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: cloudsound
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

## Support

For issues and questions:
- Check the [GitHub Issues](https://github.com/CloudSound-MKNZ/CloudSound/issues)
- Review service logs for error details
- Consult the [Developer Guide](development.md)

