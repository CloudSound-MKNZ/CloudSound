# Facebook Event Sync Troubleshooting Guide

## Problem: Events Not Creating Concerts

When clicking "Sync Events" in the frontend, Facebook events are fetched but concerts aren't being created.

## Event Flow

1. **Frontend** → Calls `/api/v1/events/poll` endpoint
2. **Event Manager** → Fetches events from Facebook API
3. **Producer** → Publishes events to Event Hubs topic `raw-events`
4. **Consumer** → Consumes from `raw-events` topic
5. **Pipeline** → Parses → Enriches → Links to concerts
6. **Linking Service** → Creates/updates concerts via HTTP API

## Common Issues

### 1. Consumer Not Running

**Symptoms**: Events are published but never processed

**Check**:
```bash
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "event_pipeline_consumer"
```

**Should see**: `event_pipeline_consumer_started_async` or `event_pipeline_consumer_starting`

**Fix**: If consumer isn't starting, check for:
- Kafka/Event Hubs connection errors
- Missing environment variables
- Consumer thread crash

### 2. Event Hubs Connection Issues

**Symptoms**: Producer/consumer can't connect to Event Hubs

**Check environment variables**:
```bash
kubectl exec -n cloudsound deployment/cloudsound-event-manager -- env | grep KAFKA
```

**Required variables**:
- `KAFKA_BOOTSTRAP_SERVERS` - Event Hubs endpoint
- `KAFKA_SECURITY_PROTOCOL=SASL_SSL`
- `KAFKA_SASL_MECHANISM=PLAIN`
- `KAFKA_SASL_USERNAME=$ConnectionString`
- `KAFKA_SASL_PASSWORD=<connection string>`

**Check logs**:
```bash
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "kafka.*connect\|sasl\|event.*hub"
```

**Fix**: Ensure Event Hubs secret exists and contains correct values:
```bash
kubectl get secret -n cloudsound eventhubs-connection-string -o yaml
```

### 3. Events Published But Not Consumed

**Symptoms**: Producer logs show events sent, but no consumer logs

**Check producer logs**:
```bash
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "raw_event_published\|kafka_message_sent"
```

**Check consumer logs**:
```bash
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "kafka_message_received\|event_pipeline_message"
```

**Possible causes**:
- Consumer group offset issue (consumer already processed messages)
- Topic doesn't exist in Event Hubs
- Consumer crashed silently

**Fix**: 
- Reset consumer group offset (if needed)
- Check if topic `raw-events` exists in Event Hubs
- Restart consumer: `kubectl rollout restart deployment/cloudsound-event-manager -n cloudsound`

### 4. Consumer Running But Not Processing

**Symptoms**: Consumer logs show messages received but no processing

**Check processing logs**:
```bash
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "event_pipeline_completed\|event_parse\|concert.*created"
```

**Possible causes**:
- Events failing validation in parser
- Enrichment service failing
- Linking service failing to create concerts

**Check for errors**:
```bash
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "error\|failed\|exception" | tail -20
```

### 5. Concert Creation API Failing

**Symptoms**: Events processed but concerts not created

**Check linking service logs**:
```bash
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "concert.*create\|linking.*failed\|concert_service"
```

**Check concert-management service**:
```bash
kubectl logs -n cloudsound deployment/cloudsound-concert-management | tail -20
```

**Possible causes**:
- Concert management service not reachable
- Authentication failure (JWT token issue)
- API endpoint changed
- Database connection issue

**Test concert creation manually**:
```bash
# Port forward to event-manager
kubectl port-forward -n cloudsound svc/cloudsound-event-manager 8002:80

# Trigger a poll
curl -X POST http://localhost:8002/api/v1/events/poll

# Check status
curl http://localhost:8002/api/v1/events/status
```

## Debugging Steps

### Step 1: Run Diagnostic Script

```bash
./scripts/debug-event-sync.sh
```

This will check:
- Deployment status
- Environment variables
- Recent logs
- Event Hubs configuration

### Step 2: Check Consumer Status

```bash
# Check if consumer thread is running
kubectl exec -n cloudsound deployment/cloudsound-event-manager -- ps aux | grep python

# Check consumer logs specifically
kubectl logs -n cloudsound deployment/cloudsound-event-manager --tail=200 | grep -i consumer
```

### Step 3: Test Event Flow Manually

```bash
# 1. Port forward to event-manager
kubectl port-forward -n cloudsound svc/cloudsound-event-manager 8002:80

# 2. Trigger a poll
curl -X POST http://localhost:8002/api/v1/events/poll

# 3. Watch logs in real-time
kubectl logs -f -n cloudsound deployment/cloudsound-event-manager
```

Look for:
- `facebook_poll_started` - Poll initiated
- `facebook_page_polled` - Events fetched
- `raw_event_published` - Event published to Event Hubs
- `kafka_message_received` - Consumer received message
- `event_pipeline_completed` - Event processed
- `concert.*created` - Concert created

### Step 4: Check Event Hubs

If using Azure Event Hubs, verify:
1. Event Hub namespace exists
2. Event Hub `raw-events` exists (or check what topic name is used)
3. Connection string is correct
4. Consumer group `event-manager` exists

### Step 5: Verify Concert Management Service

```bash
# Check if service is running
kubectl get deployment -n cloudsound cloudsound-concert-management

# Check service logs
kubectl logs -n cloudsound deployment/cloudsound-concert-management --tail=50

# Test API endpoint
kubectl port-forward -n cloudsound svc/cloudsound-concert-management 8005:80
curl http://localhost:8005/api/v1/concerts
```

## Quick Fixes

### Restart Everything

```bash
kubectl rollout restart deployment/cloudsound-event-manager -n cloudsound
kubectl rollout restart deployment/cloudsound-concert-management -n cloudsound
```

### Check All Environment Variables

```bash
kubectl exec -n cloudsound deployment/cloudsound-event-manager -- env | sort
```

### Verify Event Hubs Secret

```bash
kubectl get secret -n cloudsound eventhubs-connection-string -o jsonpath='{.data}' | \
  python3 -c "import sys, json, base64; d=json.load(sys.stdin); \
  print('bootstrap-servers:', base64.b64decode(d.get('bootstrap-servers', '')).decode() if 'bootstrap-servers' in d else 'NOT SET'); \
  print('username:', base64.b64decode(d.get('username', '')).decode() if 'username' in d else 'NOT SET'); \
  print('password:', base64.b64decode(d.get('password', '')).decode()[:50] + '...' if 'password' in d else 'NOT SET')"
```

## Expected Log Flow

When sync works correctly, you should see:

```
facebook_poll_started poll_id=1
facebook_page_polled page_id=137101232817215 event_count=5 fetch_days_back=30
raw_event_published event_id=fb_123 name=Concert Name
kafka_message_received topic=raw-events partition=0 offset=123
event_pipeline_message_received topic=raw-events key=fb_123
event_pipeline_completed event_id=fb_123 action=created concert_id=abc123
```

If any step is missing, that's where the issue is.

## Most Likely Issue

Based on the code, the most common issue is:

**The consumer thread starts but crashes silently** or **can't connect to Event Hubs**.

Check logs for:
- `kafka_consumer_connection_failed`
- `kafka_consume_error`
- `event_pipeline_consumer_stopped` (unexpectedly)

If you see these, the Event Hubs connection string or credentials are likely wrong.
