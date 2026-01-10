# CloudSound Azure Issues - Fixes Applied

## Backup Created
✅ **Backup Location**: `./backups/azure_backup_20260110_145658/`
- All Kubernetes resources exported
- Helm release configurations backed up
- Pod logs and status information saved
- Compressed archive: `./backups/azure_backup_20260110_145658.tar.gz`

## Issues Identified

### 1. ImagePullBackOff Issues
**Services Affected:**
- ❌ Kafka (Bitnami chart)
- ❌ RabbitMQ (Bitnami chart)
- ❌ Grafana
- ❌ Prometheus node-exporter
- ❌ kube-state-metrics

**Root Cause**: These services are trying to pull images from Azure Container Registry (ACR) `cloudsoundacrmgo77h.azurecr.io`, but the infrastructure images don't exist there. They should pull from public registries (Docker Hub, Bitnami registry).

**Fix Applied**: Updated Helm values to use public registries:
- Kafka: `docker.io/bitnami/kafka:3.6.0-debian-11-r1`
- RabbitMQ: `docker.io/bitnami/rabbitmq:3.12.8-debian-11-r1`
- Grafana: `docker.io/grafana/grafana:10.2.0`
- Prometheus node-exporter: `docker.io/prom/node-exporter:v1.6.1`
- kube-state-metrics: `docker.io/k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.10.0`

### 2. Authentication CrashLoopBackOff
**Status**: ⚠️ Investigating

**Symptoms**: 
- Pod restarts continuously (363 restarts)
- Container exits with code 0 (success)
- Logs show: "Uvicorn running on http://0.0.0.0:8000" but code expects port 8006

**Possible Causes**:
- Port mismatch (environment variable PORT=8000 overriding code)
- Health check failing
- Process exiting after successful startup

**Next Steps**: Check authentication pod logs and health probe configuration

### 3. PostgreSQL Pending
**Status**: ⚠️ Resource Constraint

**Root Cause**: Azure AKS nodes have volume count limits. Standard_B2s VMs support maximum 4 volumes per node. With 2 nodes = 8 total volumes, but we have many PVCs.

**Current PVCs**:
- ✅ Bound: Grafana, Prometheus, Kafka (3x), RabbitMQ, Loki (read-0, write-0, write-2)
- ❌ Pending: PostgreSQL, Loki (read-1, read-2, write-1)

**Fix Applied**: Reduced Loki replicas to free up volumes:
- Loki read replicas: 3 → 1
- Loki write replicas: 3 → 1

**Alternative Solutions**:
1. Use Azure Database for PostgreSQL (external, no PVC needed)
2. Upgrade to larger VM sizes with higher volume limits
3. Consolidate storage classes

## Fix Script

Run the fix script to apply all fixes:
```bash
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound
./scripts/fix-azure-issues.sh
```

## Monitoring

After applying fixes, monitor pod status:
```bash
# Watch all pods
kubectl get pods -n cloudsound -w

# Check specific services
kubectl get pods -n cloudsound | grep -E "(kafka|rabbitmq|grafana|authentication|postgres)"

# Check pod logs
kubectl logs <pod-name> -n cloudsound

# Check PVC status
kubectl get pvc -n cloudsound
```

## Next Steps

1. ✅ Run fix script to update image registries
2. ⏳ Monitor pod recovery (wait 5-10 minutes)
3. ⏳ Investigate authentication service port issue
4. ⏳ Consider using Azure Database for PostgreSQL
5. ⏳ Review storage class configuration for better volume management

## Notes

- The backup contains all current state information
- Helm values can be reviewed in: `./backups/azure_backup_20260110_145658/helm/`
- All Kubernetes manifests are in: `./backups/azure_backup_20260110_145658/kubernetes/`

