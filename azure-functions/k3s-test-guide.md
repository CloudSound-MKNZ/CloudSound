# Testing Azure Functions with k3s Kafka

This guide shows how to test the metadata extraction function locally while connecting to Kafka running in your k3s cluster.

## Prerequisites

1. **k3s cluster running** with Kafka deployed
2. **kubectl** configured to access your k3s cluster
3. **Python 3.11+** with dependencies installed

## Setup

### 1. Install Dependencies

```bash
cd azure-functions
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Port-Forward Kafka Service

To access Kafka from your local machine, create a port-forward:

```bash
# Find Kafka service in your cluster
kubectl get svc -n cloudsound | grep kafka

# Port-forward Kafka (default port 9092)
kubectl port-forward svc/kafka 9092:9092 -n cloudsound
```

Keep this terminal open while testing.

### 3. Test with MP3 Files

#### Option A: Test Single File

```bash
python test_k3s.py /path/to/track.mp3 --kafka-bootstrap localhost:9092
```

#### Option B: Test Directory of MP3s

```bash
python test_k3s.py /path/to/mp3/directory --kafka-bootstrap localhost:9092
```

#### Option C: Test Without Kafka (Metadata Only)

```bash
python test_k3s.py /path/to/track.mp3 --no-kafka
```

## What Happens

1. **Metadata Extraction**: Extracts ID3 tags and audio properties from MP3 files
2. **JSON Output**: Saves metadata to `./metadata_output/` directory
3. **Kafka Publishing**: Publishes events to `music.metadata.extracted` topic
4. **Logging**: Shows progress and results

## Example Output

```
2025-01-15 10:30:00 - INFO - Found 3 MP3 file(s)
2025-01-15 10:30:00 - INFO - Output directory: ./metadata_output
2025-01-15 10:30:00 - INFO - Kafka: localhost:9092 (topic: music.metadata.extracted)

2025-01-15 10:30:01 - INFO - Processing: track1.mp3
2025-01-15 10:30:02 - INFO - ✅ Extracted: Song Title by Artist Name
2025-01-15 10:30:02 - INFO -    Saved to: ./metadata_output/track1.json
2025-01-15 10:30:02 - INFO -    Published to Kafka: ✅

============================================================
Processing complete:
  ✅ Success: 3
  ❌ Failed: 0
  📁 Metadata JSON files: ./metadata_output
```

## Verify Kafka Events

### Check Kafka Topic

```bash
# Port-forward to Kafka pod (if needed)
kubectl port-forward pod/kafka-0 9092:9092 -n cloudsound

# Consume messages from topic
kubectl exec -it kafka-0 -n cloudsound -- \
  kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic music.metadata.extracted \
    --from-beginning
```

### Check with k9s

```bash
k9s
# Navigate to Kafka pod
# View logs to see message consumption
```

## Troubleshooting

### Kafka Connection Failed

**Error**: `Failed to create Kafka producer`

**Solutions**:
1. Verify port-forward is running: `kubectl get pods -n cloudsound | grep kafka`
2. Check Kafka service: `kubectl get svc kafka -n cloudsound`
3. Try different port: `kubectl port-forward svc/kafka 9093:9092 -n cloudsound`
4. Use `--kafka-bootstrap localhost:9093` in test script

### No MP3 Files Found

**Error**: `No MP3 files found`

**Solutions**:
1. Check file extension (case-sensitive): `.mp3` or `.MP3`
2. Verify path: `ls -la /path/to/files`
3. Use absolute path: `/home/user/music/track.mp3`

### Metadata Extraction Fails

**Error**: `Failed to extract metadata`

**Solutions**:
1. Verify MP3 file is valid: `file track.mp3`
2. Check if file has ID3 tags (some MP3s may not have metadata)
3. Try with `--no-kafka` to isolate the issue

## Advanced Usage

### Custom Kafka Topic

```bash
python test_k3s.py /path/to/mp3s \
  --kafka-bootstrap localhost:9092 \
  --kafka-topic custom.metadata.topic
```

### Custom Output Directory

```bash
python test_k3s.py /path/to/mp3s \
  --kafka-bootstrap localhost:9092 \
  --output-dir /tmp/metadata
```

### With Kafka Security (SASL)

```bash
python test_k3s.py /path/to/mp3s \
  --kafka-bootstrap localhost:9092 \
  --kafka-security-protocol SASL_PLAINTEXT \
  --kafka-sasl-username user \
  --kafka-sasl-password pass
```

## Integration with Music Discovery Service

After testing, the metadata events published to Kafka can be consumed by:

1. **Radio Streaming Service**: Updates track metadata in database
2. **Analytics Service**: Tracks metadata extraction metrics
3. **Admin Management Service**: Shows metadata in admin interface

## Next Steps

1. ✅ Test locally with k3s Kafka
2. ✅ Verify metadata extraction works
3. ✅ Confirm Kafka events are published
4. 🚀 Deploy to Azure when ready
5. 🔄 Update Music Discovery Service to upload to Azure Blob Storage

## See Also

- [Serverless Function Documentation](../docs/SERVERLESS_FUNCTION.md)
- [Azure Functions README](README.md)
- [Local Testing Script](test_local.py)

