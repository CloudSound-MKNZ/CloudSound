# Azure Container Registry (ACR) Configuration Summary

## Current Status

### ✅ ACR Registry
- **Registry**: `cloudsoundacrmgo77h.azurecr.io`
- **Secret**: `acr-secret` (configured in namespace `cloudsound`)

### ✅ Images in ACR
All CloudSound service images are stored in ACR with the following naming convention (without `cloudsound-` prefix):

| Service | ACR Repository | Status |
|---------|---------------|--------|
| API Gateway | `api-gateway` | ✅ Available |
| Authentication | `authentication` | ✅ Available |
| Radio Streaming | `radio-streaming` | ✅ Available |
| Concert Management | `concert-management` | ✅ Available |
| Analytics | `analytics` | ✅ Available |
| Music Discovery | `music-discovery` | ✅ Available |
| Event Manager | `event-manager` | ✅ Available |
| Frontend | `frontend` | ✅ Available |

### ✅ Helm Configuration Updates

1. **Updated `values.yaml`**: Removed `cloudsound-` prefix from all repository names to match ACR
2. **Updated `values-azure.yaml`**: Set `imageRegistry: "cloudsoundacrmgo77h.azurecr.io"` and `imagePullSecrets`
3. **Updated Helm templates**: Added `imagePullSecrets` to all service deployments

### ⚠️ Image Update Status

Most images are from **January 9, 2026** and need to be rebuilt with latest code:
- **Current Git Commit**: `3c00329`
- **Latest Image Tag in ACR**: `c62ce33` (older commit)

**Services needing rebuild**:
- analytics (2026-01-09)
- api-gateway (2026-01-09)
- concert-management (2026-01-09)
- music-discovery (2026-01-09)
- radio-streaming (2026-01-09)
- frontend (2026-01-09)

**Services already updated**:
- authentication (2026-01-27)
- event-manager (2026-01-27)

### 📝 Next Steps

1. **Rebuild and push latest images**:
   ```bash
   export REGISTRY=cloudsoundacrmgo77h.azurecr.io
   ./scripts/build-and-push-azure.sh
   ```

2. **Upgrade Helm release** (after fixing password requirements):
   ```bash
   helm upgrade cloudsound ./infrastructure/helm/cloudsound \
     -n cloudsound \
     --set global.imageRegistry=cloudsoundacrmgo77h.azurecr.io \
     --set global.imagePullSecrets[0].name=acr-secret \
     --values infrastructure/helm/cloudsound/values-azure.yaml
   ```

3. **Verify pods are pulling from ACR**:
   ```bash
   kubectl get pods -n cloudsound -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}' | grep cloudsound
   ```

### 🔧 Configuration Files

- **Helm Values**: `infrastructure/helm/cloudsound/values.yaml` (updated)
- **Azure Values**: `infrastructure/helm/cloudsound/values-azure.yaml` (configured)
- **Build Script**: `scripts/build-and-push-azure.sh`

### 📌 Notes

- All images now use consistent naming without `cloudsound-` prefix
- `imagePullSecrets` are configured in all deployment templates
- ACR registry is hardcoded in `values-azure.yaml` for Azure deployments
- Migrations/seedData use `cloudsound-shared` (not in ACR yet - may need to be built or disabled)
