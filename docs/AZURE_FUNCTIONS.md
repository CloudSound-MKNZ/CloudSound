# Azure Functions Deployment Guide

Complete guide for deploying CloudSound serverless functions to Azure Functions.

## Overview

CloudSound uses Azure Functions for serverless processing:
- **Metadata Extractor**: Extracts metadata from audio files (Kafka-triggered)

## Prerequisites

- Azure CLI installed and configured
- Azure Functions Core Tools v4
- Python 3.11
- Active Azure subscription

## Installation

### 1. Install Azure Functions Core Tools

#### Linux/WSL

```bash
# Install Microsoft package repository
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update

# Install Azure Functions Core Tools
sudo apt-get install azure-functions-core-tools-4
```

#### macOS

```bash
brew tap azure/functions
brew install azure-functions-core-tools@4
```

#### Windows

```powershell
# Using npm
npm install -g azure-functions-core-tools@4 --unsafe-perm true

# Or using Chocolatey
choco install azure-functions-core-tools-4
```

### 2. Verify Installation

```bash
func --version
# Should show 4.x.x
```

## Local Development & Testing

### 1. Navigate to Functions Directory

```bash
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound/azure-functions
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Local Settings

```bash
# Copy example settings
cp local.settings.json.example local.settings.json

# Edit with your local Kafka/Storage settings
nano local.settings.json
```

Example `local.settings.json`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "KAFKA_BOOTSTRAP_SERVERS": "localhost:9092",
    "KAFKA_TOPIC_AUDIO_UPLOAD": "audio-upload",
    "STORAGE_CONNECTION_STRING": "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;"
  }
}
```

### 4. Run Locally

```bash
# Start the functions host
func start

# In another terminal, test the function
cd azure-functions
python test_local.py
```

### 5. Test with Local Kafka

```bash
# Start local Kafka (if using Docker Compose)
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound
./scripts/start.sh

# Produce test message
python azure-functions/test_local.py
```

## Azure Deployment

### Method 1: Using Azure CLI (Recommended)

#### 1. Create Resource Group (if not exists)

```bash
az group create \
  --name cloudsound-rg \
  --location eastus
```

#### 2. Create Storage Account

```bash
# Generate unique name
STORAGE_NAME="cloudsoundfunc$(openssl rand -hex 4)"

az storage account create \
  --name $STORAGE_NAME \
  --resource-group cloudsound-rg \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2
```

#### 3. Create Function App

```bash
az functionapp create \
  --resource-group cloudsound-rg \
  --name cloudsound-metadata-extractor \
  --storage-account $STORAGE_NAME \
  --consumption-plan-location eastus \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --os-type Linux
```

#### 4. Configure Application Settings

```bash
# Get Kafka bootstrap servers (from AKS)
KAFKA_SERVERS=$(kubectl get svc -n cloudsound kafka -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9092

# Get storage connection string (from Terraform)
cd infrastructure/terraform
STORAGE_CONN=$(terraform output -raw storage_connection_string)
cd ../..

# Set app settings
az functionapp config appsettings set \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --settings \
    KAFKA_BOOTSTRAP_SERVERS="$KAFKA_SERVERS" \
    KAFKA_TOPIC_AUDIO_UPLOAD="audio-upload" \
    STORAGE_CONNECTION_STRING="$STORAGE_CONN" \
    FUNCTIONS_WORKER_PROCESS_COUNT=4
```

#### 5. Deploy Function

```bash
cd azure-functions

# Deploy
func azure functionapp publish cloudsound-metadata-extractor

# Verify deployment
func azure functionapp list-functions cloudsound-metadata-extractor
```

### Method 2: Using VS Code

1. Install **Azure Functions extension** for VS Code
2. Open `azure-functions` folder
3. Click **Azure icon** in sidebar
4. Sign in to Azure
5. Click **Deploy to Function App**
6. Select subscription and function app
7. Confirm deployment

### Method 3: Using GitHub Actions (CI/CD)

Create `.github/workflows/deploy-functions.yml`:

```yaml
name: Deploy Azure Functions

on:
  push:
    branches:
      - main
    paths:
      - 'azure-functions/**'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd azure-functions
          pip install -r requirements.txt
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to Azure Functions
        run: |
          cd azure-functions
          func azure functionapp publish cloudsound-metadata-extractor
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka broker addresses | Yes |
| `KAFKA_TOPIC_AUDIO_UPLOAD` | Topic to listen for uploads | Yes |
| `STORAGE_CONNECTION_STRING` | Azure Storage connection | Yes |
| `FUNCTIONS_WORKER_PROCESS_COUNT` | Worker processes (default: 1) | No |

### Kafka Configuration

For production Kafka (in AKS):

```bash
# Option 1: Expose Kafka with LoadBalancer
kubectl patch svc kafka -n cloudsound -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IP
KAFKA_IP=$(kubectl get svc kafka -n cloudsound -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Option 2: Use Azure Event Hubs (Kafka-compatible)
# Create Event Hubs namespace
az eventhubs namespace create \
  --resource-group cloudsound-rg \
  --name cloudsound-events \
  --location eastus \
  --sku Standard

# Get connection string
az eventhubs namespace authorization-rule keys list \
  --resource-group cloudsound-rg \
  --namespace-name cloudsound-events \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString \
  --output tsv
```

## Testing Deployed Function

### 1. Test HTTP Trigger (if available)

```bash
# Get function URL
FUNCTION_URL=$(az functionapp function show \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --function-name metadata_extractor \
  --query invokeUrlTemplate -o tsv)

# Test
curl -X POST $FUNCTION_URL -d '{"test": "data"}'
```

### 2. Test Kafka Trigger

```bash
# Produce message to Kafka
kubectl exec -it kafka-0 -n cloudsound -- kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic audio-upload

# Type message and press Enter:
{"audio_id": "test-123", "file_path": "/uploads/test.mp3"}
```

### 3. Check Function Logs

```bash
# Stream logs
func azure functionapp logstream cloudsound-metadata-extractor

# Or in Azure Portal:
# Function App > cloudsound-metadata-extractor > Log stream
```

## Monitoring

### Application Insights

Function App automatically creates Application Insights. View metrics:

```bash
# Get instrumentation key
az functionapp config appsettings list \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --query "[?name=='APPINSIGHTS_INSTRUMENTATIONKEY'].value" \
  --output tsv

# View in portal
# https://portal.azure.com > Application Insights > cloudsound-metadata-extractor
```

### Metrics to Monitor

- **Invocation count**: Number of function executions
- **Execution duration**: Time per execution
- **Failure rate**: Failed executions
- **Kafka lag**: Consumer lag (if available)

### Alerts

Create alert for failures:

```bash
az monitor metrics alert create \
  --name function-failure-alert \
  --resource-group cloudsound-rg \
  --scopes $(az functionapp show --name cloudsound-metadata-extractor --resource-group cloudsound-rg --query id -o tsv) \
  --condition "count FunctionExecutionCount where ResultType includes 'Error' > 5" \
  --description "Alert when function fails more than 5 times" \
  --evaluation-frequency 5m \
  --window-size 15m
```

## Scaling

### Consumption Plan (Default)

- **Auto-scales** based on load
- **Cost**: Pay per execution
- **Limits**: 200 instances max

### Premium Plan (For Production)

```bash
# Create Premium plan
az functionapp plan create \
  --resource-group cloudsound-rg \
  --name cloudsound-premium-plan \
  --location eastus \
  --sku EP1 \
  --is-linux true

# Update function app to use premium plan
az functionapp update \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --plan cloudsound-premium-plan
```

Benefits:
- **Always warm** instances (no cold start)
- **VNet integration** (connect to private resources)
- **Unlimited execution duration**

### Configure Scaling

```bash
az functionapp config set \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --prewarmed-instance-count 2 \
  --always-on true
```

## Troubleshooting

### Function Not Triggering

Check Kafka connection:

```bash
# View function app logs
func azure functionapp logstream cloudsound-metadata-extractor

# Check Kafka connectivity
az functionapp config appsettings list \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg
```

### Import Errors

Ensure all dependencies are in `requirements.txt`:

```bash
cd azure-functions
pip freeze > requirements.txt
```

### Kafka Connection Timeout

If Kafka is inside AKS:

1. **Option 1**: Expose Kafka with LoadBalancer
2. **Option 2**: Use VNet integration (Premium plan)
3. **Option 3**: Use Azure Event Hubs instead

### Storage Connection Issues

Check storage account firewall:

```bash
az storage account update \
  --resource-group cloudsound-rg \
  --name $STORAGE_NAME \
  --default-action Allow
```

## Cost Optimization

### Consumption Plan Costs

- **Execution time**: $0.000016/GB-s
- **Executions**: $0.20 per million
- **Monthly free grant**: 400,000 GB-s and 1 million executions

### Reduce Costs

1. **Optimize execution time** - Reduce function duration
2. **Batch processing** - Process multiple messages at once
3. **Use appropriate timeout** - Don't set unnecessarily high
4. **Monitor and adjust** - Remove unused functions

### Cost Monitoring

```bash
# View costs in Azure Portal
# Cost Management + Billing > Cost analysis

# Or use CLI
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --output table
```

## Security

### Managed Identity

Enable system-assigned managed identity:

```bash
az functionapp identity assign \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg

# Grant access to Key Vault
FUNCTION_IDENTITY=$(az functionapp identity show \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --query principalId -o tsv)

az keyvault set-policy \
  --name cloudsound-kv \
  --object-id $FUNCTION_IDENTITY \
  --secret-permissions get list
```

### Secure Kafka Connection

Use SASL/SSL for Kafka:

```bash
az functionapp config appsettings set \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --settings \
    KAFKA_SECURITY_PROTOCOL="SASL_SSL" \
    KAFKA_SASL_MECHANISM="PLAIN" \
    KAFKA_SASL_USERNAME="$KAFKA_USER" \
    KAFKA_SASL_PASSWORD="$KAFKA_PASSWORD"
```

## Cleanup

```bash
# Delete Function App
az functionapp delete \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg

# Delete storage account (if not used by other resources)
az storage account delete \
  --name $STORAGE_NAME \
  --resource-group cloudsound-rg
```

## References

- [Azure Functions Python Developer Guide](https://docs.microsoft.com/azure/azure-functions/functions-reference-python)
- [Azure Functions Best Practices](https://docs.microsoft.com/azure/azure-functions/functions-best-practices)
- [Kafka Trigger for Azure Functions](https://github.com/Azure/azure-functions-kafka-extension)
- [Application Insights](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)

---

For the main deployment guide, see [AZURE_DEPLOYMENT.md](./AZURE_DEPLOYMENT.md)

