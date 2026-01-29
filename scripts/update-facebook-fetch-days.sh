#!/bin/bash

# Quick script to update FACEBOOK_FETCH_DAYS_BACK without full Helm upgrade
# This avoids the Kafka password issue

set -e

NAMESPACE="cloudsound"
DEPLOYMENT="cloudsound-event-manager"
DAYS_BACK=${1:-30}  # Default to 30 days if not provided

echo "Updating FACEBOOK_FETCH_DAYS_BACK to $DAYS_BACK for $DEPLOYMENT..."

# Check if deployment exists
if ! kubectl get deployment -n $NAMESPACE $DEPLOYMENT &> /dev/null; then
    echo "Error: Deployment $DEPLOYMENT not found in namespace $NAMESPACE"
    exit 1
fi

# Patch the deployment to add/update the environment variable
kubectl set env deployment/$DEPLOYMENT \
    -n $NAMESPACE \
    FACEBOOK_FETCH_DAYS_BACK=$DAYS_BACK

echo "✓ Environment variable updated"

# Restart the deployment to pick up the new config
echo "Restarting deployment..."
kubectl rollout restart deployment/$DEPLOYMENT -n $NAMESPACE

echo "✓ Deployment restarted"
echo ""
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s

echo ""
echo "✓ Update complete!"
echo ""
echo "Verify with:"
echo "  kubectl exec -n $NAMESPACE deployment/$DEPLOYMENT -- env | grep FACEBOOK_FETCH_DAYS_BACK"
