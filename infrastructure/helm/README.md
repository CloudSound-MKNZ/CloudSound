# CloudSound Helm Chart

This Helm chart deploys the complete CloudSound Radio Platform to Kubernetes.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+
- kubectl configured to access your cluster
- Ingress controller (nginx-ingress recommended)
- Storage class for persistent volumes

## Quick Start

```bash
# Add required Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Update chart dependencies
cd infrastructure/helm/cloudsound
helm dependency update

# Install (development)
helm install cloudsound . --namespace cloudsound --create-namespace

# Install (production)
helm install cloudsound . \
  --namespace cloudsound \
  --create-namespace \
  -f values-production.yaml \
  --set secrets.secretKey="your-secure-secret-key" \
  --set postgresql.auth.password="secure-db-password" \
  --set rabbitmq.auth.password="secure-mq-password" \
  --set minio.auth.rootPassword="secure-minio-password" \
  --set grafana.adminPassword="secure-grafana-password"
```

## Configuration

See `values.yaml` for all configuration options. Key settings:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.environment` | Environment name | `development` |
| `global.imageRegistry` | Docker registry | `""` |
| `apiGateway.replicaCount` | API Gateway replicas | `2` |
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `kafka.enabled` | Enable Kafka | `true` |
| `prometheus.enabled` | Enable Prometheus | `true` |
| `grafana.enabled` | Enable Grafana | `true` |

## Services

| Service | Port | Description |
|---------|------|-------------|
| api-gateway | 8000 | Central API Gateway |
| radio-streaming | 8004 | Radio streaming service |
| concert-management | 8005 | Concert CRUD |
| authentication | 8006 | Auth service |
| analytics | 8007 | Analytics processing |
| music-discovery | 8003 | Music download service |
| event-manager | 8002 | Facebook integration |
| frontend | 3000 | SvelteKit frontend |

## Accessing Services

After installation, follow the NOTES output for access URLs.

For local development:

```bash
# Frontend
kubectl port-forward svc/cloudsound-frontend 3000:80

# API Gateway
kubectl port-forward svc/cloudsound-api-gateway 8000:80

# Grafana
kubectl port-forward svc/cloudsound-grafana 3001:80
```

## Upgrading

```bash
helm upgrade cloudsound . --namespace cloudsound
```

## Uninstalling

```bash
helm uninstall cloudsound --namespace cloudsound
kubectl delete namespace cloudsound
```

## Troubleshooting

Check pod status:
```bash
kubectl get pods -n cloudsound
kubectl describe pod <pod-name> -n cloudsound
kubectl logs <pod-name> -n cloudsound
```

Check services:
```bash
kubectl get svc -n cloudsound
kubectl get ingress -n cloudsound
```

