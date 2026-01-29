#!/bin/bash

# Upgrade only event-manager service without touching Kafka/StatefulSets
# This avoids the StatefulSet immutable field errors

set -e

NAMESPACE="cloudsound"
RELEASE_NAME="cloudsound"

echo "Upgrading event-manager service only..."

# Get current values to preserve Kafka config
echo "Getting current Helm values..."
helm get values $RELEASE_NAME -n $NAMESPACE > /tmp/current-values.yaml

# Upgrade with reuse-values to avoid Kafka StatefulSet updates
cd infrastructure/helm/cloudsound

helm upgrade $RELEASE_NAME . \
    --namespace $NAMESPACE \
    --reuse-values \
    --set eventManager.image.pullPolicy=Always \
    --wait \
    --timeout 10m

echo ""
echo "✓ Event manager upgraded successfully!"
echo ""
echo "To verify:"
echo "  kubectl rollout status deployment/cloudsound-event-manager -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE deployment/cloudsound-event-manager | grep -i 'facebook.*initialized\|poller.*enabled'"
