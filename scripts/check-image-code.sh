#!/bin/bash

# Check if the deployed Docker image has the correct code for reading FACEBOOK_PAGE_IDS
# This script checks the actual running container

set -e

NAMESPACE="cloudsound"
DEPLOYMENT="cloudsound-event-manager"

echo "=== Checking Docker Image Code ==="
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=event-manager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
    echo "✗ No event-manager pod found"
    exit 1
fi

echo "Pod: $POD_NAME"
echo ""

# Check image details
echo "1. Docker Image Info:"
kubectl get pod -n $NAMESPACE $POD_NAME -o jsonpath='{.spec.containers[0].image}' && echo ""
echo ""

# Check if main.py exists and has the page_ids parsing code
echo "2. Checking main.py for page_ids parsing:"
if kubectl exec -n $NAMESPACE $POD_NAME -- test -f /app/src/main.py 2>/dev/null; then
    echo "✓ main.py exists"
    echo ""
    echo "Checking for page_ids parsing code:"
    kubectl exec -n $NAMESPACE $POD_NAME -- grep -A 2 "Parse page IDs" /app/src/main.py 2>/dev/null || echo "  Code not found or can't read"
    echo ""
else
    echo "✗ main.py not found at /app/src/main.py"
fi

# Check if cloudsound-shared is installed and version
echo "3. Checking cloudsound-shared package:"
kubectl exec -n $NAMESPACE $POD_NAME -- python3 -c "import cloudsound_shared.config.settings as s; print('facebook_page_ids field exists:', hasattr(s.AppSettings(), 'facebook_page_ids'))" 2>/dev/null || echo "  Could not check"
echo ""

# Check actual environment variable value
echo "4. Environment Variable Check:"
FACEBOOK_PAGE_IDS=$(kubectl exec -n $NAMESPACE $POD_NAME -- env | grep "^FACEBOOK_PAGE_IDS=" | cut -d= -f2 || echo "")
if [ -n "$FACEBOOK_PAGE_IDS" ]; then
    echo "✓ FACEBOOK_PAGE_IDS is set: $FACEBOOK_PAGE_IDS"
else
    echo "✗ FACEBOOK_PAGE_IDS is NOT set"
fi
echo ""

# Test if Python can read it via app_settings
echo "5. Testing if code can read FACEBOOK_PAGE_IDS:"
kubectl exec -n $NAMESPACE $POD_NAME -- python3 << 'PYTHON_SCRIPT'
import os
import sys

# Check env var directly
env_value = os.getenv('FACEBOOK_PAGE_IDS', '')
print(f"Environment variable FACEBOOK_PAGE_IDS: '{env_value}'")
print(f"  Length: {len(env_value)}")
print(f"  Is empty: {not env_value}")

# Try to import and check settings
try:
    sys.path.insert(0, '/app')
    from cloudsound_shared.config.settings import app_settings
    
    print(f"\napp_settings.facebook_page_ids: '{app_settings.facebook_page_ids}'")
    print(f"  Length: {len(app_settings.facebook_page_ids)}")
    print(f"  Is empty: {not app_settings.facebook_page_ids}")
    
    # Test parsing
    if app_settings.facebook_page_ids:
        page_ids = [p.strip() for p in app_settings.facebook_page_ids.split(",") if p.strip()]
        print(f"\nParsed page_ids: {page_ids}")
        print(f"  Count: {len(page_ids)}")
        print(f"  Is empty list: {not page_ids}")
    else:
        print("\n✗ facebook_page_ids is empty, so page_ids will be empty list")
        
except Exception as e:
    print(f"\n✗ Error checking settings: {e}")
    import traceback
    traceback.print_exc()
PYTHON_SCRIPT

echo ""
echo "6. Checking startup logs for page_ids:"
kubectl logs -n $NAMESPACE $POD_NAME --tail=100 | grep -i "page_ids\|poller.*enabled\|facebook.*initialized" | head -10 || echo "  No relevant logs found"
echo ""

echo "=== Summary ==="
echo ""
echo "If FACEBOOK_PAGE_IDS is set but app_settings.facebook_page_ids is empty:"
echo "  → pydantic-settings is not reading the env var correctly"
echo "  → Check if field name matches env var (should be case-insensitive)"
echo ""
echo "If page_ids list is empty:"
echo "  → Poller will be disabled (poller_enabled = bool(token and page_ids))"
echo "  → Check logs for 'facebook_poller_disabled'"
echo ""
