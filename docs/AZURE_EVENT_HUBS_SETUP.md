# Azure Event Hubs Setup for CloudSound

This document describes the Azure Event Hubs integration for CloudSound, which replaces Kafka on AKS to solve volume limit constraints.

## Overview

Azure Event Hubs provides a Kafka-compatible API, allowing us to use the standard `kafka-python` library without code changes. This eliminates the need for Kafka and Zookeeper StatefulSets, freeing up PVC slots.

## Architecture

- **Kafka Client**: Updated to support SASL_SSL authentication for Event Hubs
- **Event Hubs**: Managed Kafka-compatible messaging service
- **No PVCs Required**: Event Hubs is fully managed, no persistent volumes needed

## Prerequisites

1. Terraform infrastructure deployed
2. Azure Event Hubs namespace created (via Terraform)
3. Kubernetes secrets configured

## Deployment Steps

### 1. Deploy Terraform Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

This creates:
- Event Hubs namespace with Kafka protocol enabled
- Event Hubs for: concert-events, music-events, playback-events, raw-events
- Authorization rule for Kafka access

### 2. Create Kubernetes Secrets

```bash
cd /home/tef/Gits/Cloudsound-Workspace/CloudSound
./scripts/azure-secrets.sh
```

This creates the `eventhubs-connection-string` secret with:
- `bootstrap-servers`: Event Hubs FQDN:9093
- `connection-string`: Full connection string
- `username`: $ConnectionString
- `password`: Connection string value

### 3. Deploy Helm Chart

```bash
cd infrastructure/helm/cloudsound
helm upgrade cloudsound . \
  -n cloudsound \
  -f values-azure.yaml \
  --set rabbitmq.auth.password="<password>"
```

### 4. Remove Old Kafka/Zookeeper Resources

```bash
# Delete Kafka StatefulSet
kubectl delete statefulset cloudsound-kafka -n cloudsound --cascade=orphan

# Delete Zookeeper StatefulSet  
kubectl delete statefulset cloudsound-zookeeper -n cloudsound --cascade=orphan

# Delete PVCs (optional, after verifying Event Hubs works)
kubectl delete pvc -n cloudsound -l app=kafka
kubectl delete pvc -n cloudsound -l app=zookeeper
```

## Configuration

### Helm Values (values-azure.yaml)

```yaml
kafka:
  enabled: false  # Disable Kafka on AKS
  external:
    enabled: true
    bootstrapServers: ""  # Set via secret
    securityProtocol: "SASL_SSL"
    saslMechanism: "PLAIN"
    connectionStringSecret: "eventhubs-connection-string"
```

### Environment Variables

Services automatically receive:
- `KAFKA_BOOTSTRAP_SERVERS`: Event Hubs FQDN:9093
- `KAFKA_SECURITY_PROTOCOL`: SASL_SSL
- `KAFKA_SASL_MECHANISM`: PLAIN
- `KAFKA_SASL_USERNAME`: $ConnectionString
- `KAFKA_SASL_PASSWORD`: Connection string value

## Code Compatibility

The Kafka client wrapper (`cloudsound_shared/kafka/__init__.py`) has been updated to:
1. Detect SASL configuration from environment variables
2. Automatically configure SASL_SSL for Azure Event Hubs
3. Maintain full compatibility with existing Kafka code

**No code changes required** - all existing Kafka producers and consumers work as-is.

## Event Hubs Topics

The following Event Hubs are created:
- `concert-events`: Concert creation/updates
- `music-events`: Music metadata events
- `playback-events`: Playback analytics
- `raw-events`: Raw Facebook events

## Verification

### Check Event Hubs Namespace

```bash
az eventhubs namespace show \
  --resource-group <rg-name> \
  --name <namespace-name> \
  --query "kafkaEnabled"
# Should return: true
```

### Check Kubernetes Secrets

```bash
kubectl get secret eventhubs-connection-string -n cloudsound -o yaml
```

### Test Producer/Consumer

```python
from cloudsound_shared.kafka import KafkaProducerClient

producer = KafkaProducerClient()
producer.connect()
producer.send("concert-events", {"test": "data"})
```

## Troubleshooting

### Connection Issues

1. **Check Event Hubs namespace exists**:
   ```bash
   az eventhubs namespace list --resource-group <rg-name>
   ```

2. **Verify Kafka protocol enabled**:
   ```bash
   az eventhubs namespace show --name <namespace> --query "kafkaEnabled"
   ```

3. **Check secret exists**:
   ```bash
   kubectl get secret eventhubs-connection-string -n cloudsound
   ```

### Authentication Errors

- Verify connection string is correct in secret
- Check Event Hubs authorization rule has Send/Listen permissions
- Ensure `KAFKA_SASL_USERNAME` is `$ConnectionString`

## Benefits

✅ **No Volume Limits**: Event Hubs is fully managed  
✅ **No Code Changes**: Fully compatible with existing Kafka code  
✅ **Scalable**: Auto-scales based on throughput  
✅ **Reliable**: 99.95% SLA, built-in replication  
✅ **Cost Effective**: Pay per throughput unit, no infrastructure to manage

## Cost Estimate

- **Standard Tier**: ~$10-20/month for 1 throughput unit
- **No infrastructure costs**: No VMs, storage, or maintenance
- **Scales automatically**: Pay only for what you use

## Migration Notes

1. **Existing Kafka data**: If you have existing Kafka data, you'll need to:
   - Export data from Kafka
   - Import to Event Hubs (or start fresh)

2. **Consumer Groups**: Event Hubs supports consumer groups identically to Kafka

3. **Topic Names**: Event Hubs uses "Event Hubs" instead of "Topics", but the API is identical

## References

- [Azure Event Hubs Kafka Guide](https://docs.microsoft.com/azure/event-hubs/event-hubs-for-kafka-ecosystem-overview)
- [Kafka Python Client](https://kafka-python.readthedocs.io/)

