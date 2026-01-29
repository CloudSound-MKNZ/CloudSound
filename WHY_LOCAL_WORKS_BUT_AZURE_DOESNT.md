# Why It Worked Locally But Not on Azure

## The Key Differences

### Local k3s Environment ✅

1. **Kafka Running Locally**
   - `KAFKA_BOOTSTRAP_SERVERS=localhost:9092`
   - No authentication required
   - Reliable connection, no timeouts
   - Consumer connects immediately

2. **Poller Enabled**
   - Facebook token configured
   - Page IDs parsed correctly
   - Background poller running every 30 minutes
   - Events automatically fetched and published

3. **Consumer Working**
   - Kafka consumer connects successfully
   - Processes events from `raw-events` topic
   - Creates concerts automatically

**Flow that worked:**
```
Facebook API → Poller → Kafka (localhost) → Consumer → Parse/Enrich/Link → Concerts Created ✅
```

### Azure Environment ❌

1. **Event Hubs Instead of Kafka**
   - `KAFKA_BOOTSTRAP_SERVERS=cloudsound-events-mgo77h.servicebus.windows.net:9093`
   - Requires SASL_SSL authentication
   - **Connection timeouts** (`ETIMEDOUT` errors)
   - Consumer can't connect reliably

2. **Poller Disabled**
   - Logs show: `"enabled": false`
   - Even though `FACEBOOK_PAGE_IDS` is set, `page_ids` list is empty
   - Background polling not running
   - No automatic event fetching

3. **Consumer Can't Connect**
   - Event Hubs connection timeouts
   - Even if events were published, consumer can't process them

**Flow that's broken:**
```
Facebook API → Poller (DISABLED) → Event Hubs (TIMEOUT) → Consumer (CAN'T CONNECT) → No Concerts ❌
```

## Root Causes

### 1. Event Hubs Connection Timeouts

**Symptoms:**
```
KafkaConnectionError: 110 ETIMEDOUT
Node 0 connection failed -- refreshing metadata
```

**Possible causes:**
- Network policies blocking outbound connections
- Event Hubs firewall not allowing AKS IPs
- Incorrect connection string format
- Event Hub namespace not configured for Kafka protocol
- SSL/TLS certificate issues

**Fix:**
- Check Azure Event Hubs firewall rules
- Verify Event Hub namespace has "Kafka" enabled
- Check network policies in AKS
- Verify connection string format

### 2. Poller Disabled

**Why:** `page_ids` list is empty even though `FACEBOOK_PAGE_IDS` env var is set.

**Possible causes:**
- Old Docker image doesn't have code that reads `FACEBOOK_PAGE_IDS`
- `app_settings.facebook_page_ids` not reading from env var correctly
- Environment variable not set when container starts

**Check:**
```bash
# Verify env var is set
kubectl exec -n cloudsound deployment/cloudsound-event-manager -- env | grep FACEBOOK_PAGE_IDS

# Check if code is parsing it
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "page_ids\|poller.*enabled"
```

**Fix:**
- Rebuild and push new Docker image with latest code
- Verify Helm template sets `FACEBOOK_PAGE_IDS` correctly
- Check that `app_settings.facebook_page_ids` reads from env var

### 3. Consumer Initialization Failing Silently

**Why:** Consumer starts but can't connect, fails silently.

**Check:**
```bash
kubectl logs -n cloudsound deployment/cloudsound-event-manager | grep -i "kafka_consumer\|event_pipeline_consumer"
```

**Should see:**
- `kafka_consumer_connected` - ✅ Connected
- `kafka_consumer_connection_failed` - ❌ Failed
- `event_pipeline_consumer_started_async` - ✅ Started

## Why Local Worked

**Local k3s had:**
1. ✅ Kafka running (no auth, reliable)
2. ✅ Poller enabled (page_ids parsed correctly)
3. ✅ Consumer connected (no timeouts)
4. ✅ Events processed automatically

**Azure has:**
1. ❌ Event Hubs timing out (network/auth issues)
2. ❌ Poller disabled (page_ids empty)
3. ❌ Consumer can't connect (timeouts)
4. ❌ No automatic processing

## Solutions

### Quick Fix: Bypass Event Hubs for Manual Sync

Create a `/api/v1/events/sync` endpoint that:
- Fetches events from Facebook
- Processes them directly (parse → enrich → link)
- Creates concerts without using Event Hubs

This works around Event Hubs issues for manual syncs.

### Proper Fix: Fix Event Hubs Connection

1. **Check Event Hubs Configuration:**
   ```bash
   # Verify Event Hub exists and Kafka is enabled
   az eventhubs namespace show --name cloudsound-events-mgo77h --resource-group cloudsound-rg
   ```

2. **Check Network Connectivity:**
   ```bash
   # Test connection from pod
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -v cloudsound-events-mgo77h.servicebus.windows.net:9093
   ```

3. **Check Firewall Rules:**
   - Event Hubs namespace → Networking → Allow access from AKS subnet
   - Or add AKS outbound IPs to allowed list

4. **Enable Poller:**
   - Rebuild image with latest code
   - Verify `FACEBOOK_PAGE_IDS` is parsed correctly
   - Check logs for `poller_enabled=True`

### Alternative: Use Kafka in AKS

If Event Hubs continues to have issues, deploy Kafka in AKS:
- Use Bitnami Kafka Helm chart
- Same as local setup
- No external dependencies

## Summary

**Local worked because:**
- Kafka was reliable and accessible
- Poller was enabled
- Consumer connected successfully

**Azure doesn't work because:**
- Event Hubs is timing out (network/auth)
- Poller is disabled (config issue)
- Consumer can't connect (timeouts)

The fix requires addressing both the Event Hubs connectivity AND enabling the poller.
