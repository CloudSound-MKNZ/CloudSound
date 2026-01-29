#!/bin/bash

# Helm upgrade script that handles Kafka passwords
# This is needed even when Kafka is disabled because Helm still processes the subchart

set -e

NAMESPACE="cloudsound"
RELEASE_NAME="cloudsound"

echo "Getting Kafka passwords from existing secret..."

# Get existing Kafka passwords from secret
INTER_BROKER_PASSWORD=$(kubectl get secret --namespace "$NAMESPACE" "${RELEASE_NAME}-kafka-user-passwords" -o jsonpath="{.data.inter-broker-password}" 2>/dev/null | base64 -d || echo "")

if [ -z "$INTER_BROKER_PASSWORD" ]; then
    echo "Warning: Could not get inter-broker password. Trying alternative method..."
    # Try to get from the secret directly
    INTER_BROKER_PASSWORD=$(kubectl get secret --namespace "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].data.inter-broker-password}' 2>/dev/null | base64 -d || echo "")
fi

if [ -z "$INTER_BROKER_PASSWORD" ]; then
    echo "Error: Could not retrieve Kafka passwords. Using --reuse-values instead..."
    USE_REUSE_VALUES=true
else
    echo "✓ Retrieved Kafka passwords"
    USE_REUSE_VALUES=false
fi

cd infrastructure/helm/cloudsound

# Get Facebook token from values-secrets.yaml if it exists
FB_TOKEN=""
FB_PAGE_IDS=""
if [ -f "values-secrets.yaml" ]; then
    if command -v yq &> /dev/null; then
        FB_TOKEN=$(yq eval '.secrets.facebookAccessToken' values-secrets.yaml 2>/dev/null || echo "")
        FB_PAGE_IDS=$(yq eval '.secrets.facebookPageIds' values-secrets.yaml 2>/dev/null || echo "")
    else
        FB_TOKEN=$(grep -A 1 "facebookAccessToken:" values-secrets.yaml | grep -v "facebookAccessToken:" | sed 's/.*"\(.*\)".*/\1/' | head -1)
        FB_PAGE_IDS=$(grep -A 1 "facebookPageIds:" values-secrets.yaml | grep -v "facebookPageIds:" | sed 's/.*"\(.*\)".*/\1/' | head -1)
    fi
fi

# Build Helm command
HELM_CMD="helm upgrade --install $RELEASE_NAME . --namespace $NAMESPACE --values values-azure.yaml"

if [ "$USE_REUSE_VALUES" = "true" ]; then
    HELM_CMD="$HELM_CMD --reuse-values"
    echo "Using --reuse-values to preserve existing configuration"
else
    HELM_CMD="$HELM_CMD --set kafka.auth.sasl.interBrokerPassword=$INTER_BROKER_PASSWORD"
    echo "Using retrieved Kafka passwords"
fi

# Add Facebook token if available
if [ -n "$FB_TOKEN" ] && [ "$FB_TOKEN" != "null" ] && [ "$FB_TOKEN" != "" ]; then
    HELM_CMD="$HELM_CMD --set secrets.facebookAccessToken=\"$FB_TOKEN\""
    if [ -n "$FB_PAGE_IDS" ] && [ "$FB_PAGE_IDS" != "null" ] && [ "$FB_PAGE_IDS" != "" ]; then
        HELM_CMD="$HELM_CMD --set secrets.facebookPageIds=\"$FB_PAGE_IDS\""
    fi
    echo "✓ Including Facebook token"
fi

# Add Facebook fetch days back
HELM_CMD="$HELM_CMD --set eventManager.facebook.fetchDaysBack=30"

HELM_CMD="$HELM_CMD --wait --timeout 10m"

echo ""
echo "Running Helm upgrade..."
echo "Command: $HELM_CMD"
echo ""

eval $HELM_CMD

echo ""
echo "✓ Helm upgrade complete!"
