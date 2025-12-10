# 🚀 CloudSound k3s Deployment Guide

Complete guide for deploying CloudSound MVP to k3s and monitoring with k9s.

## Prerequisites

- **k3s installed and running**
- **kubectl configured** to connect to your k3s cluster
- **Docker** installed (for building images)
- **k9s installed** (for monitoring) - see installation below

### Installing k9s

```bash
# Linux (using binary)
wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar xvf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/

# Or using package manager
# Arch Linux
yay -S k9s

# Ubuntu/Debian (using snap)
sudo snap install k9s

# macOS
brew install k9s
```

## Quick Deployment

### 1. Ensure k3s is Running

```bash
# Check if k3s is running
sudo systemctl status k3s

# If not running, start it:
sudo systemctl start k3s

# Verify kubectl works
kubectl cluster-info
```

### 2. Deploy CloudSound MVP

Run the deployment script:

```bash
cd /home/tef/Gits/CloudSound
chmod +x scripts/deploy-k3s.sh
./scripts/deploy-k3s.sh
```

This script will:
- ✅ Build Docker images for all MVP services:
  - Radio Streaming (port 8004)
  - Analytics (port 8007)
  - Concert Management (port 8005)
- ✅ Create Kubernetes namespace (`cloudsound`) and secrets
- ✅ Deploy infrastructure:
  - PostgreSQL (database)
  - MinIO (object storage)
  - Kafka (message broker)
  - RabbitMQ (message queue)
- ✅ Deploy application services
- ✅ Wait for services to be ready

### 3. Run Database Migrations

After infrastructure is ready, run migrations:

```bash
# Port-forward to PostgreSQL
kubectl port-forward -n cloudsound svc/postgres 5432:5432

# In another terminal, run migrations
cd backend/shared/db
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=cloudsound
export POSTGRES_PASSWORD=cloudsound_dev
export POSTGRES_DB=cloudsound
alembic upgrade head
```

### 4. Seed Mock Data

```bash
# Ensure PostgreSQL port-forward is still running (from step 3)
# In another terminal:
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=cloudsound
export POSTGRES_PASSWORD=cloudsound_dev
export POSTGRES_DB=cloudsound
python scripts/seed-mock-data.py
```

### 5. Access Services

Port-forward to access services (run each in a separate terminal):

```bash
# Radio Streaming API
kubectl port-forward -n cloudsound svc/radio-streaming 8004:8004
# Access: http://localhost:8004/docs

# Analytics API
kubectl port-forward -n cloudsound svc/analytics 8007:8007
# Access: http://localhost:8007/docs

# Concert Management API
kubectl port-forward -n cloudsound svc/concert-management 8005:8005
# Access: http://localhost:8005/docs

# MinIO Console
kubectl port-forward -n cloudsound svc/minio 9001:9001
# Access: http://localhost:9001 (minioadmin/minioadmin)

# RabbitMQ Management
kubectl port-forward -n cloudsound svc/rabbitmq 15672:15672
# Access: http://localhost:15672 (cloudsound/cloudsound_dev)
```

## 📊 Monitoring with k9s

k9s is a terminal UI for Kubernetes that provides an interactive way to monitor and manage your cluster.

### Starting k9s

```bash
# Start k9s in the cloudsound namespace
k9s -n cloudsound

# Or start k9s and switch namespace later
k9s
```

### k9s Navigation Basics

Once k9s starts, you'll see a list of resources. Here's how to navigate:

#### Main Views (Press these keys)

- **`:pods`** or **`pods`** - View pods
- **`:deploy`** or **`deploy`** - View deployments
- **`:svc`** or **`svc`** - View services
- **`:ns`** or **`ns`** - View namespaces
- **`:events`** or **`events`** - View events
- **`:logs`** or **`logs`** - View logs (select a pod first)
- **`:describe`** or **`describe`** - Describe resource
- **`:exec`** or **`exec`** - Execute into a pod
- **`:port-forward`** or **`pf`** - Port-forward to a service/pod

#### Common Commands

- **`/`** - Filter/search resources
- **`?`** - Show help
- **`q`** or **`Esc`** - Go back/exit
- **`Ctrl+C`** - Exit k9s
- **`:`** - Command mode (type resource name)
- **`d`** - Describe selected resource
- **`l`** - View logs for selected pod
- **`e`** - Edit resource
- **`s`** - Shell into pod (exec)
- **`p`** - Port-forward
- **`x`** - Delete resource (with confirmation)
- **`y`** - YAML view
- **`Ctrl+A`** - Show all namespaces

### Monitoring CloudSound with k9s

#### 1. View All Pods

```bash
# Start k9s
k9s -n cloudsound

# Press 'pods' or type ':pods'
# You'll see all pods in the cloudsound namespace
```

**What to look for:**
- **STATUS**: Should be `Running` (green)
- **READY**: Should show `1/1` or `2/2` (all containers ready)
- **RESTARTS**: Should be `0` (if not, check logs)

**Common issues:**
- `ImagePullBackOff` - Image not found, check image import
- `CrashLoopBackOff` - Pod keeps crashing, check logs
- `Pending` - Resource constraints or scheduling issues

#### 2. View Deployments

```bash
# In k9s, type ':deploy' or press 'deploy'
```

**What to look for:**
- **READY**: Should match **AVAILABLE** (e.g., `1/1`)
- **UP-TO-DATE**: Should match replicas
- **AGE**: How long deployment has been running

#### 3. View Services

```bash
# In k9s, type ':svc' or press 'svc'
```

**What to look for:**
- **CLUSTER-IP**: Internal IP address
- **PORT(S)**: Port mappings
- **AGE**: Service age

#### 4. View Logs

```bash
# In k9s pods view:
# 1. Select a pod (arrow keys)
# 2. Press 'l' to view logs
# 3. Press 'f' to follow logs (like tail -f)
# 4. Press 'Ctrl+F' to search in logs
```

**Useful log views:**
- **Radio Streaming**: Check for startup errors, API requests
- **Analytics**: Check for event processing
- **Concert Management**: Check for database queries
- **PostgreSQL**: Check for connection issues
- **Kafka**: Check for broker status
- **RabbitMQ**: Check for queue status

#### 5. View Events

```bash
# In k9s, type ':events' or press 'events'
```

**What to look for:**
- **Warning** events (yellow) - Usually indicate issues
- **Normal** events (green) - Normal operations
- Recent events show what's happening in real-time

#### 6. Describe Resources

```bash
# Select a pod/deployment/service
# Press 'd' to describe
```

**Useful information:**
- **Events**: Recent events for the resource
- **Conditions**: Current state conditions
- **Labels**: Resource labels
- **Annotations**: Resource annotations

#### 7. Port-Forward from k9s

```bash
# Select a service or pod
# Press 'p' to port-forward
# Enter local port (e.g., 8004)
# Access service at localhost:8004
```

#### 8. Shell into Pods

```bash
# Select a pod
# Press 's' to shell into it
# Useful for debugging
```

### k9s Quick Reference for CloudSound

| Task | k9s Command |
|------|-------------|
| View all pods | `:pods` |
| View deployments | `:deploy` |
| View services | `:svc` |
| View logs | Select pod → `l` |
| Follow logs | Select pod → `l` → `f` |
| Describe resource | Select resource → `d` |
| Port-forward | Select service → `p` |
| Shell into pod | Select pod → `s` |
| View events | `:events` |
| Filter pods | `/` then type filter |
| Switch namespace | `:ns` → select namespace |
| Exit | `q` or `Esc` |

### Monitoring Workflow

1. **Start k9s**: `k9s -n cloudsound`
2. **Check pods**: `:pods` - Ensure all are `Running`
3. **Check deployments**: `:deploy` - Ensure all are ready
4. **View logs**: Select a pod → `l` - Check for errors
5. **View events**: `:events` - Check for warnings
6. **Port-forward**: Select service → `p` - Test API endpoints

## Troubleshooting

### Pods Crashing (CrashLoopBackOff)

If pods are in `CrashLoopBackOff` status, they're starting but crashing immediately.

**Quick fix script:**
```bash
# Rebuild images and redeploy with fixes
sudo ./scripts/rebuild-and-redeploy.sh
```

**Quick diagnostic:**
```bash
# Run comprehensive troubleshooting
sudo ./scripts/troubleshoot-crashes.sh

# Or check logs manually
sudo kubectl logs -n cloudsound <pod-name> --tail=50
sudo kubectl logs -n cloudsound <pod-name> --previous  # Previous crash logs
```

**Common causes:**

1. **Database migrations not run** (most common):
   ```bash
   # Port-forward to PostgreSQL
   sudo kubectl port-forward -n cloudsound svc/postgres 5432:5432
   
   # In another terminal, run migrations
   cd backend/shared/db
   export POSTGRES_HOST=localhost
   export POSTGRES_PORT=5432
   export POSTGRES_USER=cloudsound
   export POSTGRES_PASSWORD=cloudsound_dev
   export POSTGRES_DB=cloudsound
   alembic upgrade head
   ```

2. **Kafka not ready** (analytics service):
   ```bash
   # Check Kafka status
   sudo kubectl get pods -n cloudsound -l app=kafka
   sudo kubectl logs -n cloudsound kafka-0
   
   # Wait for Kafka to be ready, then restart analytics
   sudo kubectl delete pod -n cloudsound -l app=analytics
   ```

3. **Import errors** (Python module not found):
   ```bash
   # Check if PYTHONPATH is set correctly in pod
   sudo kubectl exec -n cloudsound <pod-name> -- env | grep PYTHONPATH
   
   # Check if shared modules are present
   sudo kubectl exec -n cloudsound <pod-name> -- ls -la /app/backend/shared
   ```

4. **Database connection failed**:
   ```bash
   # Verify PostgreSQL is accessible
   sudo kubectl exec -n cloudsound <pod-name> -- nc -zv postgres 5432
   
   # Check database credentials
   sudo kubectl get secret -n cloudsound postgres-secret -o yaml
   ```

### Pods Not Starting / Timeout Waiting for Condition

If you see `error: timed out waiting for the condition`, the pod is not becoming ready. 

**Quick diagnostic:**
```bash
# Run the diagnostic script
sudo ./scripts/diagnose-pods.sh

# Or manually check:
```

Check:

```bash
# Check pod status
sudo kubectl get pods -n cloudsound

# Check specific pod status
sudo kubectl get pods -n cloudsound -l app=radio-streaming

# Describe pod to see events and conditions
sudo kubectl describe pod -n cloudsound <pod-name>

# Check pod logs
sudo kubectl logs -n cloudsound <pod-name> --tail=100

# Check logs for all pods with a label
sudo kubectl logs -n cloudsound -l app=radio-streaming --tail=100

# Check recent events
sudo kubectl get events -n cloudsound --sort-by='.lastTimestamp' | tail -20
```

**Common issues and fixes:**

1. **ImagePullBackOff** - Image not found (most common):

   **Quick fix:**
   ```bash
   # Run the fix script
   sudo ./scripts/fix-image-pull.sh
   
   # Or manually:
   # 1. Import images
   sudo ./scripts/import-images-k3s.sh
   
   # 2. Delete pods to restart them
   sudo kubectl delete pod -n cloudsound -l app=radio-streaming
   sudo kubectl delete pod -n cloudsound -l app=analytics
   sudo kubectl delete pod -n cloudsound -l app=concert-management
   ```

   **Verify images are imported:**
   ```bash
   sudo k3s ctr images ls | grep cloudsound
   ```

   **If images still not found:**
   ```bash
   # Rebuild and import images
   cd /home/tef/Gits/CloudSound
   docker build -f backend/radio-streaming/Dockerfile -t cloudsound-radio-streaming:latest .
   docker build -f backend/analytics/Dockerfile -t cloudsound-analytics:latest .
   docker build -f backend/concert-management/Dockerfile -t cloudsound-concert-management:latest .
   
   # Import into k3s
   sudo ./scripts/import-images-k3s.sh
   ```
   ```bash
   # Check if image exists
   sudo k3s ctr images ls | grep cloudsound
   
   # Import image if missing
   sudo k3s ctr images import <(docker save cloudsound-radio-streaming:latest)
   ```

2. **CrashLoopBackOff** - Pod keeps crashing:
   ```bash
   # Check logs for errors
   sudo kubectl logs -n cloudsound <pod-name> --previous
   
   # Common causes:
   # - Database connection failed (check PostgreSQL is ready)
   # - Missing environment variables
   # - Application startup errors
   ```

3. **Pending** - Pod not scheduled:
   ```bash
   # Check node resources
   sudo kubectl describe node
   
   # Check pod events
   sudo kubectl describe pod -n cloudsound <pod-name>
   ```

4. **Not Ready** - Readiness probe failing:
   ```bash
   # Check if health endpoint responds
   sudo kubectl exec -n cloudsound <pod-name> -- curl localhost:8004/health
   
   # Check readiness probe settings
   sudo kubectl describe pod -n cloudsound <pod-name> | grep -A 5 Readiness
   
   # Common causes:
   # - Application not fully started (increase initialDelaySeconds)
   # - Health endpoint not responding
   # - Dependencies not ready (database, Kafka, etc.)
   ```

5. **Kafka CrashLoopBackOff**:
   ```bash
   # Check Kafka logs
   sudo kubectl logs -n cloudsound kafka-0 --tail=50
   
   # Common issue: Kafka needs proper listener configuration
   # The deployment.yaml has been updated with correct settings
   # If still failing, restart Kafka:
   sudo kubectl delete pod -n cloudsound kafka-0
   
   # Verify Zookeeper is ready first
   sudo kubectl get pods -n cloudsound -l app=zookeeper
   ```

6. **Database Connection Issues**:
   ```bash
   # Verify PostgreSQL is ready
   sudo kubectl get pods -n cloudsound -l app=postgres
   
   # Test connection from pod
   sudo kubectl run -it --rm debug --image=postgres:15-alpine --restart=Never -n cloudsound -- \
     psql -h postgres -U cloudsound -d cloudsound -c "SELECT 1"
   ```

### Using k9s for Troubleshooting

```bash
# In k9s:
# 1. Select the pod
# 2. Press 'd' to describe (see Events section)
# 3. Press 'l' to view logs
# 4. Press 'e' to edit (if you need to change something)
# 5. Press 's' to shell into pod for debugging
```

### Services Not Accessible

```bash
# Check service endpoints
kubectl get endpoints -n cloudsound

# Check service selector matches pod labels
kubectl describe svc <service-name> -n cloudsound
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
k9s -n cloudsound
# Select postgres pod → 'l' to view logs

# Test connection from another pod
kubectl run -it --rm debug --image=postgres:15-alpine --restart=Never -n cloudsound -- \
  psql -h postgres -U cloudsound -d cloudsound
```

### Check Resource Usage

```bash
# In k9s, view pods and check CPU/MEM columns
# Or use kubectl:
kubectl top pods -n cloudsound
kubectl top nodes
```

## Cleanup

To remove everything:

```bash
# Delete entire namespace (removes all resources)
kubectl delete namespace cloudsound

# Or delete individually
kubectl delete -f infrastructure/kubernetes/radio-streaming/deployment.yaml
kubectl delete -f infrastructure/kubernetes/analytics/deployment.yaml
kubectl delete -f infrastructure/kubernetes/concert-management/deployment.yaml
# ... etc
```

## Next Steps

After successful deployment:

1. ✅ **Verify all pods are running** (use k9s)
2. ✅ **Run database migrations**
3. ✅ **Seed mock data**
4. ✅ **Test API endpoints** (port-forward and test)
5. ✅ **Monitor with k9s** (watch logs, events)
6. 🔄 **Add frontend deployment** (when ready)
7. 🔄 **Set up Ingress** (for external access)
8. 🔄 **Configure persistent volumes** (for data persistence)
9. 🔄 **Set up monitoring** (Prometheus/Grafana)

## Useful kubectl Commands

```bash
# Get all resources in namespace
kubectl get all -n cloudsound

# Watch pods (real-time updates)
kubectl get pods -n cloudsound -w

# Get pod logs
kubectl logs -n cloudsound <pod-name> -f

# Describe resource
kubectl describe pod -n cloudsound <pod-name>

# Get events (sorted by time)
kubectl get events -n cloudsound --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n cloudsound

# Get service endpoints
kubectl get endpoints -n cloudsound

# Exec into pod
kubectl exec -it -n cloudsound <pod-name> -- /bin/sh
```

## k9s Tips & Tricks

1. **Aliases**: Create aliases in `~/.k9s/config.yml` for common commands
2. **Hotkeys**: Customize hotkeys in k9s config
3. **Plugins**: Install k9s plugins for additional functionality
4. **Themes**: Customize colors in k9s config
5. **Multi-cluster**: Switch between clusters with `:ctx`

## Resources

- **k9s Documentation**: https://k9scli.io/
- **k3s Documentation**: https://k3s.io/
- **Kubernetes Documentation**: https://kubernetes.io/docs/

---

**Happy Deploying! 🚀**

For issues or questions, check the logs in k9s or use `kubectl describe` to debug.

