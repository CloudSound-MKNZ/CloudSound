#!/bin/bash

# Debug script for Facebook event sync issues on Azure
# Checks all components of the event sync pipeline

set -e

NAMESPACE="cloudsound"
DEPLOYMENT="cloudsound-event-manager"

echo "=== Facebook Event Sync Debug ==="
echo ""

# 1. Check if deployment exists and is running
echo "1. Checking event-manager deployment..."
if kubectl get deployment -n $NAMESPACE $DEPLOYMENT &> /dev/null; then
    echo "✓ Deployment exists"
    kubectl get deployment -n $NAMESPACE $DEPLOYMENT -o wide
    echo ""
else
    echo "✗ Deployment not found!"
    exit 1
fi

# 2. Check environment variables
echo "2. Checking environment variables..."
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=event-manager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_NAME" ]; then
    echo "Pod: $POD_NAME"
    echo ""
    echo "Facebook config:"
    kubectl exec -n $NAMESPACE $POD_NAME -- env | grep FACEBOOK || echo "  No FACEBOOK vars found"
    echo ""
    echo "Kafka/Event Hubs config:"
    kubectl exec -n $NAMESPACE $POD_NAME -- env | grep KAFKA || echo "  No KAFKA vars found"
    echo ""
    echo "Concert service URL:"
    kubectl exec -n $NAMESPACE $POD_NAME -- env | grep CONCERT_MANAGEMENT_URL || echo "  Not set"
    echo ""
else
    echo "✗ No pod found!"
fi

# 3. Check logs for errors
echo "3. Checking recent logs for errors..."
if [ -n "$POD_NAME" ]; then
    echo "Recent errors:"
    kubectl logs -n $NAMESPACE $POD_NAME --tail=50 | grep -i "error\|failed\|exception" | tail -10 || echo "  No errors found"
    echo ""
    echo "Kafka/Event Hubs connection:"
    kubectl logs -n $NAMESPACE $POD_NAME --tail=100 | grep -i "kafka\|event.*hub\|sasl" | tail -10 || echo "  No Kafka logs found"
    echo ""
    echo "Facebook polling:"
    kubectl logs -n $NAMESPACE $POD_NAME --tail=100 | grep -i "facebook.*poll\|event.*fetched" | tail -10 || echo "  No polling logs found"
    echo ""
    echo "Event processing:"
    kubectl logs -n $NAMESPACE $POD_NAME --tail=100 | grep -i "event.*pipeline\|concert.*created\|link.*event" | tail -10 || echo "  No processing logs found"
    echo ""
fi

# 4. Check if consumer is running
echo "4. Checking if Kafka consumer thread is running..."
if [ -n "$POD_NAME" ]; then
    kubectl exec -n $NAMESPACE $POD_NAME -- ps aux | grep -i "event.*pipeline\|consumer" || echo "  Consumer process not visible"
    echo ""
fi

# 5. Test Facebook API endpoint
echo "5. Testing Facebook API endpoints..."
if [ -n "$POD_NAME" ]; then
    echo "Status endpoint:"
    kubectl exec -n $NAMESPACE $POD_NAME -- curl -s http://localhost:8002/api/v1/events/status 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "  Failed to get status"
    echo ""
fi

# 6. Check Event Hubs secret
echo "6. Checking Event Hubs secret..."
if kubectl get secret -n $NAMESPACE eventhubs-connection-string &> /dev/null; then
    echo "✓ Event Hubs secret exists"
    echo "Keys in secret:"
    kubectl get secret -n $NAMESPACE eventhubs-connection-string -o jsonpath='{.data}' | python3 -c "import sys, json; d=json.load(sys.stdin); print('  ' + '\n  '.join(d.keys()))" 2>/dev/null || echo "  (could not list keys)"
    echo ""
else
    echo "✗ Event Hubs secret not found!"
    echo ""
fi

# 7. Check if topics exist (if we can connect)
echo "7. Summary of potential issues:"
echo ""
echo "Common issues to check:"
echo "  - Event Hubs connection string not configured correctly"
echo "  - Kafka environment variables not set (KAFKA_SECURITY_PROTOCOL, KAFKA_SASL_*)"
echo "  - Consumer thread not running (check logs for 'event_pipeline_consumer_started')"
echo "  - Events being published but not consumed (check producer vs consumer logs)"
echo "  - Concert management service not reachable"
echo "  - Facebook token expired or invalid"
echo ""
echo "To manually trigger a poll:"
echo "  kubectl port-forward -n $NAMESPACE svc/$DEPLOYMENT 8002:80"
echo "  curl -X POST http://localhost:8002/api/v1/events/poll"
echo ""
echo "To check consumer is processing:"
echo "  kubectl logs -f -n $NAMESPACE $DEPLOYMENT | grep -i 'event_pipeline\|concert.*created'"
