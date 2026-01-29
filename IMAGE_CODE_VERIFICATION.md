# Docker Image Code Verification

## The Issue

The Dockerfile installs `cloudsound-shared` from GitHub:
```dockerfile
RUN pip install --no-cache-dir git+https://github.com/CloudSound-MKNZ/cloudsound-shared.git@main
```

This means:
1. **The deployed image might have an older version** of cloudsound-shared
2. **If GitHub doesn't have the latest code**, the `facebook_page_ids` field might be missing
3. **Local code might be newer** than what's deployed

## How to Check

Run the verification script:
```bash
./scripts/check-image-code.sh
```

This will check:
1. ✅ If `main.py` has the page_ids parsing code
2. ✅ If `cloudsound-shared` has the `facebook_page_ids` field
3. ✅ If `FACEBOOK_PAGE_IDS` env var is set
4. ✅ If `app_settings.facebook_page_ids` can read it
5. ✅ If parsing works correctly

## Expected Results

### If Code is Correct ✅
```
Environment variable FACEBOOK_PAGE_IDS: '137101232817215'
app_settings.facebook_page_ids: '137101232817215'
Parsed page_ids: ['137101232817215']
  Count: 1
  Is empty list: False
```

### If Code is Missing/Old ❌
```
Environment variable FACEBOOK_PAGE_IDS: '137101232817215'
app_settings.facebook_page_ids: ''
  Length: 0
  Is empty: True
✗ facebook_page_ids is empty, so page_ids will be empty list
```

## Potential Issues

### 1. GitHub Version is Old
**Problem**: GitHub `main` branch doesn't have `facebook_page_ids` field

**Fix**: 
- Push latest cloudsound-shared code to GitHub
- Or change Dockerfile to install from local path during build

### 2. Environment Variable Not Mapped
**Problem**: pydantic-settings not reading `FACEBOOK_PAGE_IDS`

**Check**: pydantic-settings should map `FACEBOOK_PAGE_IDS` → `facebook_page_ids` automatically with `case_sensitive=False`

**Fix**: Verify field name matches (should be `facebook_page_ids`)

### 3. Field Missing in AppSettings
**Problem**: `cloudsound-shared` package doesn't have `facebook_page_ids` field

**Fix**: Update cloudsound-shared package on GitHub

## Quick Test

You can manually test in the pod:

```bash
kubectl exec -it -n cloudsound deployment/cloudsound-event-manager -- python3
```

Then run:
```python
import os
from cloudsound_shared.config.settings import app_settings

# Check env var
print("ENV VAR:", os.getenv('FACEBOOK_PAGE_IDS'))

# Check settings
print("SETTINGS:", app_settings.facebook_page_ids)

# Test parsing
page_ids = [p.strip() for p in app_settings.facebook_page_ids.split(",") if p.strip()]
print("PARSED:", page_ids)
print("IS EMPTY:", not page_ids)
```

## Solution

If the GitHub version is old, you have two options:

### Option 1: Update GitHub (Recommended)
```bash
cd cloudsound-shared
git add .
git commit -m "Add facebook_page_ids field"
git push origin main
```

Then rebuild the Docker image.

### Option 2: Use Local Path in Dockerfile
Change Dockerfile to:
```dockerfile
# Copy shared package locally instead of from GitHub
COPY ../cloudsound-shared /tmp/cloudsound-shared
RUN pip install --no-cache-dir /tmp/cloudsound-shared
```

This ensures the deployed image uses your local code.
