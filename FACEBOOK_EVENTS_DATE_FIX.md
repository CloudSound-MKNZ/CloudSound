# Facebook Events Date Range Fix

## Problem

Events weren't syncing on Azure because the Facebook poller was only fetching events **since the last poll**, not from a fixed time period. This meant:

1. **First poll**: Would fetch all events (since=None)
2. **Subsequent polls**: Only fetched NEW events since the last poll time
3. **Result**: Older events (even from 1 month ago) were missed if they weren't new

## Solution

Modified the Facebook client to **always fetch events from the past N days** (default 30 days = 1 month) instead of only fetching since the last poll. This ensures:

- ✅ All events from the past month are fetched on every poll
- ✅ Events that were missed or updated are caught
- ✅ Configurable via `FACEBOOK_FETCH_DAYS_BACK` environment variable

## Changes Made

### 1. Added Configuration Option
**File**: `cloudsound-shared/cloudsound_shared/config/settings.py`
- Added `facebook_fetch_days_back: int = 30` (defaults to 30 days = 1 month)

### 2. Updated Facebook Client
**File**: `cloudsound-event-manager/src/clients/facebook_client.py`
- Added `fetch_days_back` parameter to `__init__`
- Modified `poll_all_pages()` to always fetch from `datetime.now() - timedelta(days=fetch_days_back)` instead of since last poll
- Increased default limit to 100 events per page

### 3. Updated Main Application
**File**: `cloudsound-event-manager/src/main.py`
- Passes `app_settings.facebook_fetch_days_back` to Facebook client

### 4. Updated Helm Templates
**Files**: 
- `infrastructure/helm/cloudsound/templates/services.yaml` - Added `FACEBOOK_FETCH_DAYS_BACK` environment variable
- `infrastructure/helm/cloudsound/values.yaml` - Added `eventManager.facebook.fetchDaysBack: 30`
- `infrastructure/helm/cloudsound/values-azure.yaml` - Added `eventManager.facebook.fetchDaysBack: 30`

### 5. Updated Environment File
**File**: `cloudsound-event-manager/.env`
- Added `FACEBOOK_FETCH_DAYS_BACK=30`

## How It Works Now

```python
# Before (only fetched since last poll):
since = self._last_poll.get(page_id)  # Could be None or last poll time
response = await self.get_events(page_id=page_id, since=since)

# After (always fetches from past month):
since_date = datetime.now() - timedelta(days=self.fetch_days_back)  # Always 30 days ago
response = await self.get_events(page_id=page_id, since=since_date, limit=100)
```

## Deployment

### Option 1: Redeploy with Updated Code (Recommended)

1. **Build and push new images**:
   ```bash
   ./scripts/build-and-push-azure.sh
   ```

2. **Upgrade Helm release**:
   ```bash
   cd infrastructure/helm/cloudsound
   helm upgrade cloudsound . \
       --namespace cloudsound \
       --values values-azure.yaml \
       --set secrets.facebookAccessToken="YOUR_TOKEN" \
       --set secrets.facebookPageIds="YOUR_PAGE_IDS" \
       --wait
   ```

### Option 2: Quick Fix (Update Config Only)

If you just want to update the configuration without rebuilding:

```bash
# Update Helm values
helm upgrade cloudsound infrastructure/helm/cloudsound \
    --namespace cloudsound \
    --reuse-values \
    --set eventManager.facebook.fetchDaysBack=30 \
    --wait

# Restart pods to pick up new config
kubectl rollout restart deployment/cloudsound-event-manager -n cloudsound
```

### Option 3: Manual Environment Variable Update

```bash
# Patch the deployment to add the environment variable
kubectl set env deployment/cloudsound-event-manager \
    -n cloudsound \
    FACEBOOK_FETCH_DAYS_BACK=30

# Restart pods
kubectl rollout restart deployment/cloudsound-event-manager -n cloudsound
```

## Verification

After deployment, verify the fix:

1. **Check environment variable**:
   ```bash
   kubectl exec -n cloudsound deployment/cloudsound-event-manager -- env | grep FACEBOOK_FETCH_DAYS_BACK
   # Should show: FACEBOOK_FETCH_DAYS_BACK=30
   ```

2. **Trigger a manual poll**:
   ```bash
   kubectl port-forward -n cloudsound svc/cloudsound-event-manager 8002:80
   curl -X POST http://localhost:8002/api/v1/events/poll
   ```

3. **Check logs**:
   ```bash
   kubectl logs -f deployment/cloudsound-event-manager -n cloudsound
   # Look for: "facebook_page_polled" with "fetch_days_back": 30
   ```

4. **Check status**:
   ```bash
   curl http://localhost:8002/api/v1/events/status
   ```

## Configuration

You can customize how far back to fetch events:

- **Environment Variable**: `FACEBOOK_FETCH_DAYS_BACK=30` (default: 30 days)
- **Helm Values**: `eventManager.facebook.fetchDaysBack: 30`
- **Settings**: `facebook_fetch_days_back: int = 30` in `app_settings`

### Examples:

- **1 week**: Set to `7`
- **2 months**: Set to `60`
- **3 months**: Set to `90`

## Why This Fix Works

1. **Consistent Fetching**: Every poll fetches from the same time period (past month), ensuring no events are missed
2. **Catches Updates**: If an event is updated (time changed, description updated, etc.), it will be re-fetched
3. **Handles Missed Polls**: If a poll fails or is delayed, the next poll still gets all events from the past month
4. **Configurable**: Easy to adjust the time window based on your needs

## Notes

- The Facebook API may return duplicate events, but the downstream processing should handle deduplication
- Increasing `fetch_days_back` will fetch more events but may increase API calls and processing time
- The default limit per page is now 100 events (increased from 25) to handle more events in the time window
