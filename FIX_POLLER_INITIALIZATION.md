# Fix: Poller Initialization Issue

## Problem Found

The code **CAN** read `FACEBOOK_PAGE_IDS` correctly (verified), but at **startup time** the poller is disabled because:

1. **Environment variables ARE set correctly** ✅
   - `FACEBOOK_ACCESS_TOKEN` is set
   - `FACEBOOK_PAGE_IDS` is set

2. **But at startup, `app_settings` reads them as empty** ❌
   - `app_settings.facebook_access_token` = `None` at startup
   - `app_settings.facebook_page_ids` = `""` at startup
   - Result: `poller_enabled = False`

3. **Later, the same code CAN read them** ✅
   - After pod restart, Python can read the env vars correctly
   - But the Facebook client was already initialized in mock mode

## Root Cause

`app_settings` is a **module-level singleton** created at import time:
```python
app_settings = AppSettings()  # Created when module is imported
```

When the module is first imported (during Docker image build or early Python startup), the environment variables might not be available yet, so `app_settings` gets default values.

Even though pydantic-settings should read env vars when creating an instance, there might be a timing issue where:
- Module imports happen before Kubernetes mounts secrets
- Or pydantic-settings caches the first read

## Solution

Reload settings in the lifespan function to ensure we get fresh values:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Reload settings to ensure we have latest env vars
    from cloudsound_shared.config.settings import AppSettings
    app_settings = AppSettings()  # Fresh instance with current env vars
    
    # Now use app_settings for initialization
    page_ids = [p.strip() for p in app_settings.facebook_page_ids.split(",") if p.strip()]
    use_mock = app_settings.use_mock_apis or not app_settings.facebook_access_token
    # ... rest of initialization
```

Or, better yet, read environment variables directly in the lifespan function:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    import os
    
    # Read directly from environment (most reliable)
    facebook_token = os.getenv('FACEBOOK_ACCESS_TOKEN')
    facebook_page_ids_str = os.getenv('FACEBOOK_PAGE_IDS', '')
    page_ids = [p.strip() for p in facebook_page_ids_str.split(",") if p.strip()]
    
    use_mock = app_settings.use_mock_apis or not facebook_token
    
    facebook_client = FacebookEventsClient(
        access_token=facebook_token,
        page_ids=page_ids,
        use_mock=use_mock,
        fetch_days_back=app_settings.facebook_fetch_days_back,
    )
    
    poller_enabled = bool(facebook_token and page_ids)
    # ... rest
```

## Quick Fix

The simplest fix is to read env vars directly in the lifespan function instead of relying on `app_settings`:

1. Read `FACEBOOK_ACCESS_TOKEN` and `FACEBOOK_PAGE_IDS` directly from `os.getenv()`
2. This ensures we get the values that are actually set in the container
3. Use `app_settings` for other settings that don't have this timing issue

## Verification

After applying the fix, check logs for:
- `"has_token": true` (not false)
- `"page_count": 1` (not 0)  
- `"enabled": true` (not false)
