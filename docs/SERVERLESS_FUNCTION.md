# Serverless Function: Audio Metadata Extraction

## Overview

We use **Azure Functions** (serverless) to extract audio metadata when music files are uploaded to Azure Blob Storage. This function automatically processes MP3 files to extract:

- Track title, artist, album
- Duration, bitrate, sample rate
- Album artwork (thumbnails)
- Genre, year, track number
- ID3 tags

## Use Case

**Problem**: When music is downloaded from YouTube/Bandcamp, we need to extract metadata from the MP3 file. This is CPU-intensive and should not block the main download process.

**Solution**: Azure Function triggered by blob storage events automatically extracts metadata when files are uploaded.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Music Discovery Service                         │
│  Downloads MP3 → Uploads to Azure Blob Storage              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ (Blob Created Event)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         Azure Function (Serverless)                         │
│  • Triggered on blob upload                                 │
│  • Extracts metadata from MP3                              │
│  • Generates thumbnail from album art                       │
│  • Publishes metadata to Kafka                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ (Metadata Event)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Kafka Topic: music.metadata.extracted          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ (Consumed by)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         Radio Streaming Service                             │
│  Updates track metadata in database                         │
└─────────────────────────────────────────────────────────────┘
```

## Implementation

### Azure Function Structure

```
azure-functions/
├── metadata-extractor/
│   ├── function.json          # Function configuration
│   ├── __init__.py            # Function code
│   ├── requirements.txt       # Python dependencies
│   └── metadata_utils.py     # Metadata extraction logic
├── host.json                  # Host configuration
└── requirements.txt           # Global dependencies
```

### Function Code

**`function.json`**:

```json
{
  "scriptFile": "__init__.py",
  "bindings": [
    {
      "name": "blob",
      "type": "blobTrigger",
      "direction": "in",
      "path": "music/{name}.mp3",
      "connection": "AzureWebJobsStorage"
    },
    {
      "name": "outputBlob",
      "type": "blob",
      "direction": "out",
      "path": "metadata/{name}.json",
      "connection": "AzureWebJobsStorage"
    }
  ]
}
```

**`__init__.py`**:

```python
import logging
import json
import azure.functions as func
from metadata_utils import extract_metadata, generate_thumbnail

def main(blob: func.InputStream, outputBlob: func.Out[str]):
    """
    Azure Function triggered when MP3 file is uploaded to blob storage.
    
    Args:
        blob: Input blob stream (MP3 file)
        outputBlob: Output blob for metadata JSON
    """
    logging.info(f'Processing blob: {blob.name}, Size: {blob.length} bytes')
    
    try:
        # 1. Extract metadata from MP3
        metadata = extract_metadata(blob)
        
        # 2. Generate thumbnail from album art (if available)
        if metadata.get('album_art'):
            thumbnail_url = generate_thumbnail(
                metadata['album_art'],
                blob.name
            )
            metadata['thumbnail_url'] = thumbnail_url
        
        # 3. Add processing metadata
        metadata['processed_at'] = datetime.utcnow().isoformat()
        metadata['source_file'] = blob.name
        metadata['file_size'] = blob.length
        
        # 4. Save metadata to blob storage
        outputBlob.set(json.dumps(metadata, indent=2))
        
        # 5. Publish to Kafka for downstream processing
        publish_metadata_event(metadata)
        
        logging.info(f'Metadata extracted successfully: {metadata.get("title")}')
        
    except Exception as e:
        logging.error(f'Error processing blob {blob.name}: {str(e)}', exc_info=True)
        raise
```

**`metadata_utils.py`**:

```python
import mutagen
from mutagen.id3 import ID3
from mutagen.mp3 import MP3
from PIL import Image
import io
import base64

def extract_metadata(blob_stream) -> dict:
    """
    Extract metadata from MP3 file using mutagen library.
    
    Args:
        blob_stream: File stream of MP3 file
        
    Returns:
        Dictionary with extracted metadata
    """
    # Load MP3 file
    audio = MP3(blob_stream)
    
    metadata = {
        'title': audio.get('TIT2', ['Unknown'])[0] if 'TIT2' in audio else None,
        'artist': audio.get('TPE1', ['Unknown'])[0] if 'TPE1' in audio else None,
        'album': audio.get('TALB', ['Unknown'])[0] if 'TALB' in audio else None,
        'duration': int(audio.info.length),
        'bitrate': audio.info.bitrate,
        'sample_rate': audio.info.sample_rate,
        'genre': audio.get('TCON', ['Unknown'])[0] if 'TCON' in audio else None,
        'year': audio.get('TDRC', ['Unknown'])[0] if 'TDRC' in audio else None,
        'track_number': audio.get('TRCK', ['0'])[0] if 'TRCK' in audio else None,
    }
    
    # Extract album art
    if 'APIC:' in audio:
        album_art = audio['APIC:'].data
        metadata['album_art'] = base64.b64encode(album_art).decode('utf-8')
        metadata['album_art_mime'] = audio['APIC:'].mime
    
    return metadata

def generate_thumbnail(album_art_data: bytes, track_name: str) -> str:
    """
    Generate thumbnail from album art.
    
    Args:
        album_art_data: Base64-encoded album art image
        track_name: Track name for file naming
        
    Returns:
        URL to thumbnail in blob storage
    """
    # Decode base64 image
    image_data = base64.b64decode(album_art_data)
    image = Image.open(io.BytesIO(image_data))
    
    # Resize to thumbnail (300x300)
    image.thumbnail((300, 300), Image.Resampling.LANCZOS)
    
    # Save to blob storage
    thumbnail_name = f"thumbnails/{track_name}_thumb.jpg"
    # Upload to blob storage...
    
    return f"https://storage.azure.com/thumbnails/{thumbnail_name}"
```

### Kafka Integration

```python
from kafka import KafkaProducer
import os

def publish_metadata_event(metadata: dict):
    """Publish metadata extraction event to Kafka."""
    producer = KafkaProducer(
        bootstrap_servers=os.environ['KAFKA_BOOTSTRAP_SERVERS'],
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )
    
    event = {
        'event_type': 'music.metadata.extracted',
        'track_id': metadata.get('track_id'),
        'metadata': metadata,
        'timestamp': datetime.utcnow().isoformat()
    }
    
    producer.send('music.metadata.extracted', value=event)
    producer.flush()
```

## Deployment

### Azure Function App Setup

1. **Create Function App**:
```bash
az functionapp create \
  --resource-group cloudsound-rg \
  --consumption-plan-location westeurope \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --name cloudsound-metadata-extractor
```

2. **Configure Storage Connection**:
```bash
az functionapp config appsettings set \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --settings AzureWebJobsStorage="<storage-connection-string>"
```

3. **Configure Kafka Connection**:
```bash
az functionapp config appsettings set \
  --name cloudsound-metadata-extractor \
  --resource-group cloudsound-rg \
  --settings KAFKA_BOOTSTRAP_SERVERS="<kafka-bootstrap-servers>"
```

4. **Deploy Function**:
```bash
cd azure-functions/metadata-extractor
func azure functionapp publish cloudsound-metadata-extractor
```

### Environment Variables

- `AzureWebJobsStorage`: Azure Storage connection string
- `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses
- `KAFKA_SECURITY_PROTOCOL`: Security protocol (SASL_SSL, etc.)
- `KAFKA_API_KEY`: Kafka API key (if using Azure Event Hubs)

## Monitoring

### Function Metrics

- **Execution count**: Number of times function executed
- **Execution time**: Average processing time
- **Success rate**: Percentage of successful executions
- **Error rate**: Percentage of failed executions
- **Blob processing latency**: Time from upload to metadata extraction

### Logs

Function logs are available in:
- Azure Portal → Function App → Logs
- Application Insights (if configured)
- Log Analytics workspace

### Alerts

Configure alerts for:
- Function execution failures
- High execution time (> 30 seconds)
- High error rate (> 5%)

## Cost Optimization

### Consumption Plan Benefits

- **Pay per execution**: Only pay when function runs
- **Automatic scaling**: Scales from 0 to N instances
- **No idle costs**: No charges when not processing

### Optimization Strategies

1. **Batch processing**: Process multiple files in one execution
2. **Caching**: Cache metadata for duplicate files
3. **Async processing**: Don't block on Kafka publish
4. **Resource limits**: Set appropriate memory/timeout limits

## Integration with Music Discovery Service

The Music Discovery Service uploads files and triggers the function:

```python
# In Music Discovery Service
async def upload_to_storage(file_path: str, track_id: UUID):
    """Upload MP3 to Azure Blob Storage."""
    blob_client = blob_service_client.get_blob_client(
        container="music",
        blob=f"{track_id}.mp3"
    )
    
    with open(file_path, "rb") as data:
        blob_client.upload_blob(data, overwrite=True)
    
    # Function automatically triggered by blob upload
    # Metadata extraction happens asynchronously
```

## Benefits

1. **Scalability**: Automatically scales with load
2. **Cost-effective**: Pay only for executions
3. **Decoupling**: Metadata extraction doesn't block downloads
4. **Resilience**: Automatic retries on failure
5. **Monitoring**: Built-in metrics and logging

## Alternative: AWS Lambda / Google Cloud Functions

If not using Azure, similar implementations:

- **AWS Lambda**: Triggered by S3 events
- **Google Cloud Functions**: Triggered by Cloud Storage events

The pattern remains the same: blob storage event → serverless function → metadata extraction → publish to message queue.

