# Facebook Event Sync Fix

## Problem Identified

The Facebook event sync wasn't working on Azure because:

1. **Secret Template Issue**: The `secrets.yaml` Helm template only created the Kubernetes secret when PostgreSQL, RabbitMQ, or MinIO were enabled. In Azure, these services are external, so the secret (containing the Facebook token) was never created.

2. **Deployment Script Issue**: The `azure-deploy-all.sh` script didn't pass Facebook token values from `values-secrets.yaml` to Helm during deployment.

## Fixes Applied

### 1. Fixed `secrets.yaml` Template
**File**: `infrastructure/helm/cloudsound/templates/secrets.yaml`

**Change**: Updated the condition to also create the secret when Facebook token is provided:
```yaml
{{- if or .Values.postgresql.enabled .Values.rabbitmq.enabled .Values.minio.enabled .Values.secrets.facebookAccessToken }}
```

This ensures the secret is created even when using external services, as long as a Facebook token is provided.

### 2. Updated Deployment Script
**File**: `scripts/azure-deploy-all.sh`

**Change**: Added logic to read Facebook token from `values-secrets.yaml` and pass it to Helm:
- Checks if `values-secrets.yaml` exists
- Extracts `facebookAccessToken` and `facebookPageIds` using `yq` (or grep/sed fallback)
- Passes these values to Helm using `--set` flags

### 3. Created Verification Script
**File**: `scripts/check-facebook-config.sh`

A new script to verify Facebook token configuration:
- Checks if the token exists in Kubernetes secrets
- Verifies environment variables in the event-manager pod
- Tests the service status endpoint
- Provides troubleshooting guidance

## How to Deploy the Fix

### Option 1: Redeploy with Updated Scripts
```bash
# Make sure values-secrets.yaml contains your Facebook token
cat infrastructure/helm/cloudsound/values-secrets.yaml

# Redeploy (will use updated scripts)
./scripts/azure-deploy-all.sh
```

### Option 2: Manual Helm Upgrade
```bash
cd infrastructure/helm/cloudsound

# Read token from values-secrets.yaml
FB_TOKEN=$(grep -A 1 "facebookAccessToken:" values-secrets.yaml | grep -v "facebookAccessToken:" | sed 's/.*"\(.*\)".*/\1/' | head -1)
FB_PAGE_IDS=$(grep -A 1 "facebookPageIds:" values-secrets.yaml | grep -v "facebookPageIds:" | sed 's/.*"\(.*\)".*/\1/' | head -1)

# Upgrade Helm release
helm upgrade cloudsound . \
    --namespace cloudsound \
    --set secrets.facebookAccessToken="$FB_TOKEN" \
    --set secrets.facebookPageIds="$FB_PAGE_IDS" \
    --values values-azure.yaml \
    --wait
```

### Option 3: Direct Secret Update (Quick Fix)
If you just need to update the secret without redeploying:
```bash
# Get token from values-secrets.yaml
FB_TOKEN=$(grep -A 1 "facebookAccessToken:" infrastructure/helm/cloudsound/values-secrets.yaml | grep -v "facebookAccessToken:" | sed 's/.*"\(.*\)".*/\1/' | head -1)
FB_PAGE_IDS=$(grep -A 1 "facebookPageIds:" infrastructure/helm/cloudsound/values-secrets.yaml | grep -v "facebookPageIds:" | sed 's/.*"\(.*\)".*/\1/' | head -1)

# Update or create the secret
kubectl create secret generic cloudsound-secrets \
    --namespace cloudsound \
    --from-literal=facebook-access-token="$FB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

# Restart event-manager pods to pick up the new secret
kubectl rollout restart deployment/cloudsound-event-manager -n cloudsound
```

## Verification

After deploying, verify the configuration:

```bash
# Run the verification script
./scripts/check-facebook-config.sh

# Or manually check:
kubectl get secret cloudsound-secrets -n cloudsound -o jsonpath='{.data.facebook-access-token}' | base64 -d

# Check pod environment
kubectl exec -n cloudsound deployment/cloudsound-event-manager -- env | grep FACEBOOK

# Check service status
kubectl port-forward -n cloudsound svc/cloudsound-event-manager 8002:80
curl http://localhost:8002/api/v1/events/status
# Should show: "mock_mode": false
```

## Current Token Status

Your current Facebook token in `values-secrets.yaml`:
- **Token**: `EAADMgYSJvKcBQdDYwibeZBJ9ybLh2EhGv64ODOq14MK1YCFCO7Kv5fWQpqnhZB2KhKaZB9C0raSjYwKnDdJpmJci66GZAaybOvIGbEzlRP3CgnTBsTSGPwRHZBedb51ChxxekPpRvpuZCxm8PRdErWtpg5RZCGJp9XYJZBPjZAP0USKGaIjSihoCtR6UZCWfwRtOzlEhgZD`
- **Page ID**: `137101232817215`

**Note**: This token appears to be a Page Access Token. If it was generated from a long-lived user token, it should not expire. If you're experiencing authentication errors, verify the token is still valid using:

```bash
curl "https://graph.facebook.com/v24.0/me?access_token=YOUR_TOKEN"
```

## Next Steps

1. **Verify Current Deployment**: Run `./scripts/check-facebook-config.sh` to see if the token is currently deployed
2. **Redeploy if Needed**: If the token is missing, use one of the deployment options above
3. **Test Facebook Sync**: After deployment, check the event-manager logs:
   ```bash
   kubectl logs -f deployment/cloudsound-event-manager -n cloudsound
   ```
4. **Monitor Polling**: The Facebook poller runs every 30 minutes by default. Check the status endpoint to see when it last ran.
