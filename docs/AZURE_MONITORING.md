# Azure Monitoring & Observability Guide

Complete guide for monitoring CloudSound on Azure with Azure Monitor, Application Insights, and integrated observability stack.

## Overview

CloudSound monitoring stack includes:
- **Azure Monitor**: Container insights, logs, and metrics
- **Application Insights**: Application performance monitoring (APM)
- **Prometheus**: Metrics collection
- **Grafana**: Metrics visualization
- **Loki**: Log aggregation
- **Azure Log Analytics**: Centralized logging

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Azure Monitor                        │
│  ┌────────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │   Container    │  │     Log      │  │  Application│ │
│  │   Insights     │  │  Analytics   │  │   Insights  │ │
│  └────────────────┘  └──────────────┘  └─────────────┘ │
└───────────────────────────┬─────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │         AKS Cluster                  │
         │  ┌──────────┐    ┌─────────────┐   │
         │  │Prometheus│◄───┤  Services   │   │
         │  └────┬─────┘    └─────────────┘   │
         │       │                              │
         │       ▼                              │
         │  ┌──────────┐    ┌─────────────┐   │
         │  │ Grafana  │    │    Loki     │   │
         │  └──────────┘    └─────────────┘   │
         └─────────────────────────────────────┘
```

## Azure Monitor Setup

### 1. Enable Container Insights

```bash
# Enable monitoring for AKS
az aks enable-addons \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --addons monitoring

# Check status
az aks show \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --query "addonProfiles.omsagent.enabled" \
  -o tsv
```

### 2. Create Log Analytics Workspace (if not exists)

```bash
# Create workspace
az monitor log-analytics workspace create \
  --resource-group cloudsound-rg \
  --workspace-name cloudsound-logs \
  --location eastus

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group cloudsound-rg \
  --workspace-name cloudsound-logs \
  --query id -o tsv)

# Link to AKS
az aks enable-addons \
  --resource-group cloudsound-rg \
  --name cloudsound-aks \
  --addons monitoring \
  --workspace-resource-id $WORKSPACE_ID
```

### 3. Verify Setup

```bash
# Check monitoring pods
kubectl get pods -n kube-system | grep omsagent

# Should see:
# omsagent-xxxxx     (running on each node)
# omsagent-rs-xxxxx  (replica set)
```

## Application Insights Integration

### 1. Create Application Insights Resource

```bash
# Create Application Insights
az monitor app-insights component create \
  --app cloudsound-insights \
  --location eastus \
  --resource-group cloudsound-rg \
  --application-type web \
  --workspace $WORKSPACE_ID

# Get instrumentation key
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app cloudsound-insights \
  --resource-group cloudsound-rg \
  --query instrumentationKey -o tsv)

# Get connection string
CONNECTION_STRING=$(az monitor app-insights component show \
  --app cloudsound-insights \
  --resource-group cloudsound-rg \
  --query connectionString -o tsv)

echo "Instrumentation Key: $INSTRUMENTATION_KEY"
echo "Connection String: $CONNECTION_STRING"
```

### 2. Configure Applications

#### Add to Kubernetes Secrets

```bash
kubectl create secret generic app-insights-secret \
  --namespace cloudsound \
  --from-literal=instrumentation-key=$INSTRUMENTATION_KEY \
  --from-literal=connection-string=$CONNECTION_STRING \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Update Deployments

Add environment variables to all services:

```yaml
# Example: api-gateway deployment
env:
- name: APPLICATIONINSIGHTS_CONNECTION_STRING
  valueFrom:
    secretKeyRef:
      name: app-insights-secret
      key: connection-string
- name: APPINSIGHTS_INSTRUMENTATIONKEY
  valueFrom:
    secretKeyRef:
      name: app-insights-secret
      key: instrumentation-key
```

#### Python Integration

Install SDK in services:

```python
# Add to requirements.txt
opencensus-ext-azure==1.1.9
opencensus-ext-flask==0.7.6

# Add to main.py
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.trace.samplers import ProbabilitySampler
import logging
import os

# Configure logging
logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(
    connection_string=os.getenv('APPLICATIONINSIGHTS_CONNECTION_STRING')
))

# Configure tracing
middleware = FlaskMiddleware(
    app,
    exporter=AzureExporter(
        connection_string=os.getenv('APPLICATIONINSIGHTS_CONNECTION_STRING')
    ),
    sampler=ProbabilitySampler(rate=1.0),
)

# Use in code
logger.info("Service started")
logger.error("Error occurred", extra={'custom_property': 'value'})
```

## Prometheus & Grafana

### 1. Install Prometheus Stack

```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Prometheus, Grafana, Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set grafana.adminPassword='YourSecurePassword' \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.ingressClassName=nginx \
  --set grafana.ingress.hosts[0]=monitoring.cloudsound.example.com \
  --wait
```

### 2. Access Grafana

```bash
# Get admin password
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port forward (for testing)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access: http://localhost:3000
# Username: admin
# Password: (from above)
```

### 3. Configure Service Monitors

Create `ServiceMonitor` for CloudSound services:

```yaml
# cloudsound-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cloudsound-services
  namespace: cloudsound
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: cloudsound
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

Apply:

```bash
kubectl apply -f cloudsound-servicemonitor.yaml
```

### 4. Import Grafana Dashboards

Import these dashboard IDs in Grafana:
- **315**: Kubernetes Cluster Monitoring
- **13332**: Kubernetes API Server
- **12006**: Kubernetes Pods
- **6417**: Kubernetes Cluster Overview

Or create custom dashboard for CloudSound:

```json
{
  "dashboard": {
    "title": "CloudSound Overview",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{namespace=\"cloudsound\"}[5m])"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{namespace=\"cloudsound\",status=~\"5..\"}[5m])"
          }
        ]
      },
      {
        "title": "Response Time (p95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace=\"cloudsound\"}[5m]))"
          }
        ]
      }
    ]
  }
}
```

## Loki (Log Aggregation)

### 1. Install Loki Stack

```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki stack (includes Loki, Promtail, Grafana)
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set promtail.enabled=true \
  --set grafana.enabled=false \
  --wait
```

### 2. Configure Grafana Data Source

Add Loki as data source in Grafana:

```bash
kubectl port-forward -n monitoring svc/loki 3100:3100
```

In Grafana:
1. Configuration → Data Sources → Add data source
2. Select "Loki"
3. URL: `http://loki.monitoring.svc.cluster.local:3100`
4. Save & Test

### 3. Query Logs

Example LogQL queries:

```logql
# All logs from cloudsound namespace
{namespace="cloudsound"}

# Logs from api-gateway
{namespace="cloudsound", app="api-gateway"}

# Error logs
{namespace="cloudsound"} |= "error" or "ERROR"

# HTTP 500 errors
{namespace="cloudsound"} | json | status="500"

# Logs with rate
rate({namespace="cloudsound"}[5m])
```

## Azure Log Analytics Queries

### Access Log Analytics

Azure Portal → Log Analytics workspaces → cloudsound-logs → Logs

### Useful KQL Queries

#### Container Logs

```kql
ContainerLog
| where Namespace == "cloudsound"
| where TimeGenerated > ago(1h)
| project TimeGenerated, ContainerName, LogEntry
| order by TimeGenerated desc
```

#### Performance Metrics

```kql
Perf
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores"
| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart
```

#### Error Count

```kql
ContainerLog
| where Namespace == "cloudsound"
| where LogEntry contains "error" or LogEntry contains "exception"
| summarize ErrorCount = count() by bin(TimeGenerated, 1h), ContainerName
| render barchart
```

#### Pod Restarts

```kql
KubePodInventory
| where Namespace == "cloudsound"
| where PodRestartCount > 0
| summarize RestartCount = max(PodRestartCount) by PodName
| order by RestartCount desc
```

## Alerts Configuration

### 1. Azure Monitor Alerts

#### High CPU Usage Alert

```bash
az monitor metrics alert create \
  --name high-cpu-alert \
  --resource-group cloudsound-rg \
  --scopes $(az aks show -n cloudsound-aks -g cloudsound-rg --query id -o tsv) \
  --condition "avg Percentage CPU > 80" \
  --description "Alert when CPU usage is above 80%" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 2
```

#### High Memory Usage Alert

```bash
az monitor metrics alert create \
  --name high-memory-alert \
  --resource-group cloudsound-rg \
  --scopes $(az aks show -n cloudsound-aks -g cloudsound-rg --query id -o tsv) \
  --condition "avg Memory Working Set Percentage > 80" \
  --description "Alert when memory usage is above 80%" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 2
```

#### Pod Restart Alert

```bash
az monitor metrics alert create \
  --name pod-restart-alert \
  --resource-group cloudsound-rg \
  --scopes $(az aks show -n cloudsound-aks -g cloudsound-rg --query id -o tsv) \
  --condition "total restartingContainerCount > 5" \
  --description "Alert when pods restart more than 5 times" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 1
```

### 2. Prometheus Alerts

Create `PrometheusRule`:

```yaml
# cloudsound-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cloudsound-alerts
  namespace: cloudsound
  labels:
    release: prometheus
spec:
  groups:
  - name: cloudsound
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: |
        rate(http_requests_total{status=~"5..",namespace="cloudsound"}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} errors/sec"
    
    - alert: HighResponseTime
      expr: |
        histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="cloudsound"}[5m])) > 2
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High response time detected"
        description: "P95 response time is {{ $value }}s"
    
    - alert: PodNotReady
      expr: |
        kube_pod_status_ready{condition="false",namespace="cloudsound"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.pod }} is not ready"
        description: "Pod has been not ready for 5 minutes"
```

Apply:

```bash
kubectl apply -f cloudsound-alerts.yaml
```

### 3. Action Groups (Notifications)

```bash
# Create action group for email notifications
az monitor action-group create \
  --name cloudsound-alerts \
  --resource-group cloudsound-rg \
  --short-name csalerts \
  --email-receiver \
    name=admin-email \
    email-address=admin@example.com

# Add action group to alerts
az monitor metrics alert update \
  --name high-cpu-alert \
  --resource-group cloudsound-rg \
  --add-action $(az monitor action-group show --name cloudsound-alerts --resource-group cloudsound-rg --query id -o tsv)
```

## Dashboards

### Azure Portal Dashboards

1. Go to Azure Portal → Dashboards
2. Create new dashboard
3. Add tiles:
   - **AKS Cluster metrics**
   - **Container CPU/Memory**
   - **Log Analytics queries**
   - **Application Insights metrics**

### Grafana Dashboards

Import or create dashboards for:
- **Cluster Overview**: Node status, resource usage
- **CloudSound Services**: Request rate, errors, latency
- **Database**: PostgreSQL metrics
- **Message Brokers**: Kafka/RabbitMQ metrics
- **Storage**: MinIO/Blob storage metrics

## Distributed Tracing

### OpenTelemetry Integration

Install OpenTelemetry in services:

```python
# requirements.txt
opentelemetry-api
opentelemetry-sdk
opentelemetry-instrumentation-fastapi
azure-monitor-opentelemetry-exporter

# main.py
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from azure.monitor.opentelemetry.exporter import AzureMonitorTraceExporter

# Configure tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Export to Application Insights
exporter = AzureMonitorTraceExporter(
    connection_string=os.getenv('APPLICATIONINSIGHTS_CONNECTION_STRING')
)

trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(exporter)
)

# Instrument FastAPI
FastAPIInstrumentor.instrument_app(app)
```

## Cost Optimization

### Monitor Costs

```bash
# View monitoring costs
az consumption usage list \
  --start-date $(date -d "30 days ago" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  | jq '[.[] | select(.instanceName | contains("log") or contains("insight"))] | group_by(.instanceName) | map({name: .[0].instanceName, cost: (map(.pretaxCost) | add)})'
```

### Reduce Costs

1. **Adjust retention periods**:
   ```bash
   az monitor log-analytics workspace update \
     --resource-group cloudsound-rg \
     --workspace-name cloudsound-logs \
     --retention-time 30  # Days
   ```

2. **Use sampling** in Application Insights (set `sampler=ProbabilitySampler(rate=0.1)`)

3. **Filter logs** - Don't send debug logs to production

4. **Set data caps**:
   ```bash
   az monitor app-insights component update \
     --app cloudsound-insights \
     --resource-group cloudsound-rg \
     --cap 5  # GB per day
   ```

## Troubleshooting

### No Data in Container Insights

```bash
# Check omsagent pods
kubectl get pods -n kube-system | grep omsagent

# View logs
kubectl logs -n kube-system -l component=oms-agent
```

### Prometheus Not Scraping

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n cloudsound

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090/targets
```

### Grafana Not Showing Data

```bash
# Test Prometheus connectivity from Grafana pod
kubectl exec -it -n monitoring prometheus-grafana-xxx -- wget -O- http://prometheus-kube-prometheus-prometheus:9090/api/v1/query?query=up
```

## Best Practices

1. **Set up alerts** for critical metrics
2. **Use dashboards** for visualization
3. **Enable distributed tracing** for debugging
4. **Set retention policies** to control costs
5. **Monitor your monitoring** - Set alerts on monitoring system health
6. **Use namespaces** to organize resources
7. **Tag resources** for cost tracking
8. **Regular reviews** of dashboards and alerts

## References

- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [Application Insights](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)

---

For the main deployment guide, see [AZURE_DEPLOYMENT.md](./AZURE_DEPLOYMENT.md)

