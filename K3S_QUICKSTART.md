# k3s Deployment Guide - CloudSound

This guide shows you how to deploy CloudSound to a **local k3s cluster** for testing.

## Prerequisites

- **k3s installed and running** on your machine
- **kubectl configured** to connect to your k3s cluster
- **Docker** installed (for building images)
- **k3s registry** (optional, for image registry)

## Quick Start

### 1. Ensure k3s is Running

```bash
# Check if k3s is running
sudo systemctl status k3s

# If not running, start it:
sudo systemctl start k3s

# Verify kubectl works
kubectl cluster-info
```

### 2. Build and Deploy

Run the deployment script:

```bash
cd /home/tef/Gits/CloudSound
./scripts/deploy-k3s.sh
```

This script will:
- Build Docker images for radio-streaming and analytics services
- Create Kubernetes namespace and secrets
- Deploy infrastructure (PostgreSQL, MinIO, Kafka, RabbitMQ)
- Deploy application services
- Wait for services to be ready

### 3. Run Database Migrations

After infrastructure is ready, run migrations:

```bash
# Option 1: Run migrations in a temporary pod
kubectl run migration --image=python:3.11-slim --rm -it --restart=Never -n cloudsound -- \
  sh -c "pip install alembic asyncpg && cd /tmp && ..."

# Option 2: Port-forward and run locally
kubectl port-forward -n cloudsound svc/postgres 5432:5432
# Then run migrations from your local machine
```

**Note**: For now, you may need to run migrations manually. A proper migration job will be added later.

### 4. Seed Mock Data

```bash
# Port-forward to PostgreSQL
kubectl port-forward -n cloudsound svc/postgres 5432:5432

# In another terminal, run the seed script
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=cloudsound
export POSTGRES_PASSWORD=cloudsound_dev
export POSTGRES_DB=cloudsound
python scripts/seed-mock-data.py
```

### 5. Access Services

Port-forward to access services:

```bash
# Radio Streaming API
kubectl port-forward -n cloudsound svc/radio-streaming 8004:8004

# Analytics API
kubectl port-forward -n cloudsound svc/analytics 8007:8007

# MinIO Console
kubectl port-forward -n cloudsound svc/minio 9001:9001

# RabbitMQ Management
kubectl port-forward -n cloudsound svc/rabbitmq 15672:15672
```

Then access:
- Radio Streaming API: http://localhost:8004
- API Docs: http://localhost:8004/docs
- MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
- RabbitMQ Management: http://localhost:15672 (cloudsound/cloudsound_dev)

## Manual Deployment Steps

If you prefer to deploy manually:

### 1. Create Namespace and Secrets

```bash
kubectl apply -f infrastructure/kubernetes/base/namespace.yaml
kubectl apply -f infrastructure/kubernetes/base/secrets.yaml
kubectl apply -f infrastructure/kubernetes/base/configmap.yaml
```

### 2. Build Docker Images

```bash
# Build radio-streaming
cd backend/radio-streaming
docker build -t cloudsound-radio-streaming:latest .

# Build analytics
cd ../analytics
docker build -t cloudsound-analytics:latest .
```

### 3. Import Images to k3s

k3s uses containerd, so import images directly:

```bash
# Import radio-streaming
sudo k3s ctr images import <(docker save cloudsound-radio-streaming:latest)

# Import analytics
sudo k3s ctr images import <(docker save cloudsound-analytics:latest)
```

### 4. Deploy Infrastructure

```bash
kubectl apply -f infrastructure/kubernetes/postgresql/deployment.yaml
kubectl apply -f infrastructure/kubernetes/minio/deployment.yaml
kubectl apply -f infrastructure/kubernetes/kafka/deployment.yaml
kubectl apply -f infrastructure/kubernetes/rabbitmq/deployment.yaml
```

### 5. Deploy Services

```bash
kubectl apply -f infrastructure/kubernetes/radio-streaming/deployment.yaml
kubectl apply -f infrastructure/kubernetes/analytics/deployment.yaml
```

## Check Status

```bash
# View all pods
kubectl get pods -n cloudsound

# View services
kubectl get svc -n cloudsound

# View logs
kubectl logs -n cloudsound -l app=radio-streaming
kubectl logs -n cloudsound -l app=analytics

# Describe a pod (for debugging)
kubectl describe pod -n cloudsound <pod-name>
```

## Troubleshooting

### Images Not Found

If pods show `ImagePullBackOff`:
- Make sure images are imported: `sudo k3s ctr images ls | grep cloudsound`
- Update deployment to use `imagePullPolicy: IfNotPresent` (already set)

### Services Not Starting

- Check logs: `kubectl logs -n cloudsound <pod-name>`
- Check events: `kubectl get events -n cloudsound --sort-by='.lastTimestamp'`
- Verify secrets exist: `kubectl get secrets -n cloudsound`

### Database Connection Issues

- Ensure PostgreSQL is ready: `kubectl get pods -n cloudsound -l app=postgres`
- Check PostgreSQL logs: `kubectl logs -n cloudsound -l app=postgres`
- Verify service: `kubectl get svc -n cloudsound postgres`

### Port Forwarding Issues

- Make sure the service exists: `kubectl get svc -n cloudsound`
- Check if port is already in use: `lsof -i :8004`

## Cleanup

To remove everything:

```bash
# Delete all resources in namespace
kubectl delete namespace cloudsound

# Or delete individually
kubectl delete -f infrastructure/kubernetes/radio-streaming/deployment.yaml
kubectl delete -f infrastructure/kubernetes/analytics/deployment.yaml
# ... etc
```

## Next Steps

- Add Ingress for external access
- Set up proper migration jobs
- Add frontend deployment
- Configure persistent volumes for data
- Set up monitoring (Prometheus/Grafana)

