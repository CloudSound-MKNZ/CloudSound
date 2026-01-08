# Azure Functions: Audio Metadata Extractor

Serverless function for extracting metadata from MP3 files uploaded to Azure Blob Storage.

## Overview

This Azure Function is triggered when MP3 files are uploaded to the `music/` container in Azure Blob Storage. It:

1. Extracts metadata (title, artist, album, duration, etc.) from MP3 files
2. Generates thumbnails from album art (if available)
3. Saves metadata as JSON to blob storage
4. Publishes metadata events to Kafka for downstream processing

## Local Development

### Prerequisites

1. **Azure Functions Core Tools**:
   ```bash
   # macOS
   brew tap azure/functions
   brew install azure-functions-core-tools@4
   
   # Linux
   curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
   sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
   sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoftubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
   sudo apt-get update
   sudo apt-get install azure-functions-core-tools-4
   
   # Windows (via npm)
   npm install -g azure-functions-core-tools@4 --unsafe-perm true
   ```

2. **Python 3.11+**

3. **Local Kafka** (for testing):
   ```bash
   # Using Docker Compose from CloudSound project
   cd ../infrastructure/docker
   docker compose -f docker-compose.dev.yml up -d kafka
   ```

### Setup

1. **Copy local settings**:
   ```bash
   cp local.settings.json.example local.settings.json
   ```

2. **Edit `local.settings.json`**:
   - Set `KAFKA_BOOTSTRAP_SERVERS` to your Kafka broker
   - Configure Azure Storage connection (or use `UseDevelopmentStorage=true` for local emulator)

3. **Install dependencies**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

4. **Run locally**:
   ```bash
   func start
   ```

### Testing Locally

#### Option 1: Test with k3s Kafka (Recommended)

Test the function with MP3 files while connecting to Kafka in your k3s cluster:

```bash
# 1. Port-forward Kafka service
kubectl port-forward svc/kafka 9092:9092 -n cloudsound

# 2. In another terminal, test with MP3 files
python test_k3s.py /path/to/mp3/files --kafka-bootstrap localhost:9092

# Or test single file
python test_k3s.py /path/to/track.mp3 --kafka-bootstrap localhost:9092
```

This will:
- Extract metadata from MP3 files
- Save metadata JSON to `./metadata_output/`
- Publish events to Kafka in k3s

See [k3s Testing Guide](k3s-test-guide.md) for detailed instructions.

#### Option 2: Manual Trigger (HTTP)

For local testing without blob storage, you can create an HTTP trigger version:

```python
# test_metadata_extractor.py
import requests
import json

# Read a local MP3 file
with open('test.mp3', 'rb') as f:
    files = {'file': f}
    response = requests.post('http://localhost:7071/api/ExtractMetadata', files=files)
    print(json.dumps(response.json(), indent=2))
```

#### Option 2: Blob Storage Emulator

1. Install Azure Storage Emulator or Azurite
2. Configure `AzureWebJobsStorage` to point to emulator
3. Upload test MP3 file to blob storage

#### Option 3: Direct Function Call

```python
# test_local.py
import sys
sys.path.append('.')
from metadata_extractor import main
from metadata_extractor.metadata_utils import extract_metadata
import io

# Read test MP3
with open('test.mp3', 'rb') as f:
    blob_data = f.read()
    blob_stream = io.BytesIO(blob_data)
    
    # Extract metadata
    metadata = extract_metadata(blob_stream, 'test.mp3')
    print(json.dumps(metadata, indent=2))
```

## Deployment to Azure

### Prerequisites

1. **Azure CLI** installed and logged in:
   ```bash
   az login
   ```

2. **Function App** created in Azure:
   ```bash
   az functionapp create \
     --resource-group cloudsound-rg \
     --consumption-plan-location westeurope \
     --runtime python \
     --runtime-version 3.11 \
     --functions-version 4 \
     --name cloudsound-metadata-extractor \
     --storage-account <storage-account-name>
   ```

### Deploy

1. **Configure app settings**:
   ```bash
   az functionapp config appsettings set \
     --name cloudsound-metadata-extractor \
     --resource-group cloudsound-rg \
     --settings \
       KAFKA_BOOTSTRAP_SERVERS="<kafka-bootstrap-servers>" \
       KAFKA_METADATA_TOPIC="music.metadata.extracted" \
       KAFKA_SECURITY_PROTOCOL="SASL_SSL" \
       KAFKA_SASL_MECHANISM="PLAIN" \
       KAFKA_SASL_USERNAME="<kafka-username>" \
       KAFKA_SASL_PASSWORD="<kafka-password>"
   ```

2. **Deploy function**:
   ```bash
   func azure functionapp publish cloudsound-metadata-extractor
   ```

3. **Configure blob trigger**:
   - The function is automatically triggered when files are uploaded to `music/` container
   - Ensure the storage account connection string is configured in app settings

## Function Structure

```
azure-functions/
├── host.json                    # Host configuration
├── requirements.txt             # Python dependencies
├── local.settings.json         # Local settings (gitignored)
├── metadata_extractor/          # Function app
│   ├── function.json           # Function bindings
│   ├── __init__.py             # Function entry point
│   ├── metadata_utils.py        # Metadata extraction logic
│   └── kafka_utils.py          # Kafka integration
└── README.md                    # This file
```

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AzureWebJobsStorage` | Azure Storage connection string | `DefaultEndpointsProtocol=https;AccountName=...` |
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka broker addresses | `localhost:9092` or `kafka1:9092,kafka2:9092` |
| `KAFKA_METADATA_TOPIC` | Kafka topic for metadata events | `music.metadata.extracted` |
| `KAFKA_SECURITY_PROTOCOL` | Kafka security protocol | `SASL_SSL` or empty for plain |
| `KAFKA_SASL_MECHANISM` | SASL mechanism | `PLAIN` |
| `KAFKA_SASL_USERNAME` | Kafka username | `user` |
| `KAFKA_SASL_PASSWORD` | Kafka password | `password` |

### Blob Storage Structure

```
storage-account/
├── music/              # Input: MP3 files uploaded here
│   ├── track1.mp3
│   └── track2.mp3
└── metadata/           # Output: Extracted metadata JSON
    ├── track1.json
    └── track2.json
```

## Monitoring

### Azure Portal

- **Function App** → **Functions** → **metadata_extractor** → **Monitor**
- View execution logs, success/failure rates, execution times

### Application Insights

If configured, view:
- Function execution metrics
- Dependency tracking (Kafka calls)
- Exception logs

### Logs

```bash
# Stream logs
az functionapp log tail \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg
```

## Testing

### Test with Sample MP3

1. Upload a test MP3 file to blob storage:
   ```bash
   az storage blob upload \
     --account-name <storage-account> \
     --container-name music \
     --name test.mp3 \
     --file test.mp3
   ```

2. Check function execution in Azure Portal

3. Verify metadata JSON in `metadata/test.json`

4. Check Kafka topic for event:
   ```bash
   kafka-console-consumer \
     --bootstrap-server <kafka-server> \
     --topic music.metadata.extracted \
     --from-beginning
   ```

## Troubleshooting

### Function Not Triggering

- Check blob storage connection string
- Verify container name is `music`
- Check function logs for errors

### Metadata Extraction Fails

- Verify MP3 file is valid
- Check function logs for mutagen errors
- Some MP3 files may not have ID3 tags

### Kafka Publish Fails

- Verify Kafka connection settings
- Check network connectivity
- Review Kafka broker logs
- Function will still save metadata to blob storage even if Kafka fails

## Cost Optimization

- **Consumption Plan**: Pay only for executions
- **Timeout**: Set appropriate timeout (default 5 minutes)
- **Memory**: Adjust based on file sizes (default 1.5GB)

## Integration

This function integrates with:

1. **Music Discovery Service**: Uploads MP3 files to blob storage
2. **Kafka**: Publishes metadata events for downstream processing
3. **Radio Streaming Service**: Consumes metadata events to update track information

See [Serverless Function Documentation](../docs/SERVERLESS_FUNCTION.md) for architecture details.

