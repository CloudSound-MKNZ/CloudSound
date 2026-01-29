# Multi-Repo Deployment (Option B)

CloudSound uses **Option B**: each microservice is built and pushed from its **own repository**. The main CloudSound repo builds only **frontend** and **migrations** (cloudsound-shared) and deploys to AKS using images from Azure Container Registry (ACR).

## Overview

| Repo | Builds | Pushes to |
|------|--------|-----------|
| **CloudSound** (this repo) | frontend, cloudsound-shared (migrations) | ACR |
| **cloudsound-api-gateway** | api-gateway image | ACR |
| **cloudsound-authentication** | authentication image | ACR |
| **cloudsound-radio-streaming** | radio-streaming image | ACR |
| **cloudsound-concert-management** | concert-management image | ACR |
| **cloudsound-analytics** | analytics image | ACR |
| **cloudsound-music-discovery** | music-discovery image | ACR |
| **cloudsound-event-manager** | event-manager image | ACR |
| **cloudsound-admin-management** | admin-management image | ACR |

## Syncing code and making workflows visible on GitHub

The workflow file (`.github/workflows/build-and-push-azure.yml`) and service code live in your **local** clones of each `cloudsound-*` repo. **They do not appear on GitHub until you push.**

1. **Sync code from CloudSound into each service repo** (so each repo has the same code as `CloudSound/backend/<service>`):
   ```bash
   cd /path/to/CloudSound
   ./scripts/sync-and-push-service-repos.sh
   ```

2. **Push each repo to GitHub** so the workflow shows under Actions:
   ```bash
   cd /path/to/cloudsound-radio-streaming   # repeat for each repo
   git add -A
   git status   # you should see .github/workflows/build-and-push-azure.yml and any synced files
   git commit -m "Add ACR build workflow and sync code from CloudSound"
   git push origin main
   ```
   Or run the script with `--push` to be prompted for each repo:
   ```bash
   ./scripts/sync-and-push-service-repos.sh --push
   ```

After pushing, each repo’s **Actions** tab will show **“Build and Push to ACR”**, and you can run it manually or on push to `main`.

## Workflow

1. **Service repos**: On push to `main` or `production`, each microservice repo runs `.github/workflows/build-and-push-azure.yml`, builds its Docker image, and pushes to ACR as `<acr>/<service-name>:latest` and `:<sha>`.

2. **CloudSound repo**: On push to `main` or `production`, or on manual trigger, `.github/workflows/deploy-to-azure.yml` runs. It:
   - Builds and pushes **frontend** and **cloudsound-shared** (migrations) to ACR.
   - Deploys to AKS via Helm, pulling **all** service images from ACR (backend images were pushed by service repos).

3. **First-time or full deploy**: Ensure every backend service has pushed at least once to ACR (e.g. push to main in each repo), then run the CloudSound deploy workflow so Helm can pull `:latest` for every service.

## Required secrets

### CloudSound repo (main repo)

- `ACR_LOGIN_SERVER`, `ACR_USERNAME`, `ACR_PASSWORD`
- `AZURE_CREDENTIALS`
- `POSTGRES_HOST`, `DOMAIN_NAME`, and any others listed in [SECRETS_SETUP.md](../.github/SECRETS_SETUP.md)

### Each microservice repo (cloudsound-radio-streaming, etc.)

Each repo needs ACR secrets so its workflow can push the image. You can either:

- **Option A – Organization-level secrets (recommended)**  
  Create ACR secrets once at the **organization** and allow access for all `cloudsound-*` repos. No need to add them per repo.  
  → Step-by-step: [SECRETS_SETUP.md – Organization-Level Secrets](../.github/SECRETS_SETUP.md#organization-level-secrets-recommended-for-option-b)

- **Option B – Per-repo secrets**  
  Add the same three secrets to each microservice repo:
  - **ACR_LOGIN_SERVER** – e.g. `yourregistry.azurecr.io`
  - **ACR_USERNAME** – ACR admin username  
  - **ACR_PASSWORD** – ACR admin password  

You can copy values from the CloudSound repo or from Terraform output (`terraform output -raw acr_login_server`, etc.).

## Local / script builds

- **CloudSound**: `./scripts/build-and-push-azure.sh` still builds **frontend** and **migrations** from this repo. It no longer builds backend services; those must be built from their repos or pushed by CI.
- **Backend images**: Build and push from each service repo (e.g. `cd cloudsound-radio-streaming && docker build -t $REGISTRY/radio-streaming:latest . && docker push $REGISTRY/radio-streaming:latest`), or rely on the workflow on push to main.

## Helm image names

Helm expects these image names in ACR (with tag `latest` or as overridden):

- `api-gateway`, `authentication`, `radio-streaming`, `concert-management`, `analytics`, `music-discovery`, `event-manager`, `frontend`, `cloudsound-shared`

Repo name `cloudsound-<service>` maps to image name `<service>` (e.g. `cloudsound-radio-streaming` → `radio-streaming`).
