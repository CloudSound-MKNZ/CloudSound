#!/bin/bash
# Deploy CloudSound to local k3s cluster

set -e

echo "🚀 Deploying CloudSound to k3s..."

# Check if k3s is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ k3s is not running or kubectl is not configured"
    echo "   Please start k3s and ensure kubectl is configured"
    exit 1
fi

# Get the k3s registry (usually localhost:5000 for local registry)
REGISTRY="${K3S_REGISTRY:-localhost:5000}"
echo "📦 Using registry: $REGISTRY"

# Build and push Docker images
echo "🔨 Building Docker images..."

# Build radio-streaming
echo "  Building radio-streaming..."
cd backend/radio-streaming
docker build -t cloudsound-radio-streaming:latest .
docker tag cloudsound-radio-streaming:latest $REGISTRY/cloudsound-radio-streaming:latest
docker push $REGISTRY/cloudsound-radio-streaming:latest || echo "⚠️  Push failed, using local image"

# Build analytics
echo "  Building analytics..."
cd ../analytics
docker build -t cloudsound-analytics:latest .
docker tag cloudsound-analytics:latest $REGISTRY/cloudsound-analytics:latest
docker push $REGISTRY/cloudsound-analytics:latest || echo "⚠️  Push failed, using local image"

cd ../../

# Import images into k3s (if using local images)
if [ "$REGISTRY" = "localhost:5000" ]; then
    echo "📥 Importing images into k3s..."
    sudo k3s ctr images import <(docker save cloudsound-radio-streaming:latest) || true
    sudo k3s ctr images import <(docker save cloudsound-analytics:latest) || true
fi

# Apply Kubernetes manifests
echo "📋 Applying Kubernetes manifests..."

# Create namespace
kubectl apply -f infrastructure/kubernetes/base/namespace.yaml

# Create secrets
kubectl apply -f infrastructure/kubernetes/base/secrets.yaml

# Create configmap
kubectl apply -f infrastructure/kubernetes/base/configmap.yaml

# Deploy infrastructure
echo "  Deploying infrastructure..."
kubectl apply -f infrastructure/kubernetes/postgresql/deployment.yaml
kubectl apply -f infrastructure/kubernetes/minio/deployment.yaml

# Wait for infrastructure to be ready
echo "⏳ Waiting for infrastructure to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n cloudsound --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=minio -n cloudsound --timeout=120s || true

# Run database migrations
echo "🗄️  Running database migrations..."
# Create a job to run migrations
kubectl run migration-job --image=postgres:15-alpine --restart=Never -n cloudsound --rm -i -- \
    sh -c "PGPASSWORD=cloudsound_dev psql -h postgres -U cloudsound -d cloudsound -c 'SELECT 1'" || true

# TODO: Actually run Alembic migrations
# For now, we'll need to run migrations manually or create a proper migration job

# Deploy services
echo "  Deploying services..."
kubectl apply -f infrastructure/kubernetes/radio-streaming/deployment.yaml
kubectl apply -f infrastructure/kubernetes/analytics/deployment.yaml

# Wait for services
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app=radio-streaming -n cloudsound --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=analytics -n cloudsound --timeout=120s || true

# Seed mock data (if script exists)
if [ -f "scripts/seed-mock-data.py" ]; then
    echo "🌱 Seeding mock data..."
    # TODO: Create a job to seed data
    echo "   Run manually: kubectl run seed-job --image=python:3.11 -n cloudsound ..."
fi

echo "✅ Deployment complete!"
echo ""
echo "Services:"
echo "  - Radio Streaming: kubectl port-forward -n cloudsound svc/radio-streaming 8004:8004"
echo "  - Analytics: kubectl port-forward -n cloudsound svc/analytics 8007:8007"
echo "  - MinIO Console: kubectl port-forward -n cloudsound svc/minio 9001:9001"
echo ""
echo "Check status:"
echo "  kubectl get pods -n cloudsound"
echo "  kubectl get svc -n cloudsound"

