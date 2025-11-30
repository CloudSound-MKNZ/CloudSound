# Environment Configuration Guide

## Overview

CloudSound uses **environment-based configuration** managed through environment variables and configuration files. This approach follows industry best practices and is **NOT** managed through Git branches.

## Best Practices

### ✅ DO:
- Use environment variables for configuration
- Use separate `.env` files for each environment
- Use ConfigMaps/Secrets in Kubernetes for production
- Use feature flags to enable/disable features per environment
- Keep example files (`.env.*.example`) in Git
- Use CI/CD pipelines to inject environment-specific values

### ❌ DON'T:
- Use Git branches for environment configuration
- Commit actual `.env` files with secrets to Git
- Hardcode environment-specific values in code
- Use the same database/credentials across environments

## Environments

### Development (`development`)
- **Purpose**: Local development on developer machines
- **Mock APIs**: Enabled
- **Mock Data**: Seeded automatically
- **Debug**: Enabled
- **Logging**: Text format, DEBUG level
- **Database**: Local PostgreSQL via Docker Compose
- **Setup**: `docker-compose -f infrastructure/docker/docker-compose.dev.yml up -d`

### Test (`test`)
- **Purpose**: Automated testing and CI/CD
- **Mock APIs**: Enabled
- **Mock Data**: Seeded automatically
- **Debug**: Disabled
- **Logging**: JSON format, INFO level
- **Database**: Isolated test database
- **Setup**: `docker-compose -f infrastructure/docker/docker-compose.test.yml up -d`

### Production (`production`)
- **Purpose**: Live production environment
- **Mock APIs**: Disabled (real APIs required)
- **Mock Data**: Never seeded
- **Debug**: Disabled
- **Logging**: JSON format, INFO level
- **Database**: Managed database service (RDS, etc.)
- **Setup**: Kubernetes deployment with ConfigMaps and Secrets

## Configuration Files

### Environment Variable Files

| File | Purpose | Git Status |
|------|---------|------------|
| `.env.development.example` | Template for development | ✅ Committed |
| `.env.test.example` | Template for test | ✅ Committed |
| `.env.production.example` | Template for production | ✅ Committed |
| `.env.development` | Actual dev config | ❌ Gitignored |
| `.env.test` | Actual test config | ❌ Gitignored |
| `.env.production` | Actual prod config | ❌ Gitignored |

### Setup Instructions

1. **Development**:
   ```bash
   cp .env.development.example .env.development
   # Edit .env.development with your local settings
   export ENVIRONMENT=development
   ```

2. **Test**:
   ```bash
   cp .env.test.example .env.test
   # Edit .env.test with test settings
   export ENVIRONMENT=test
   ```

3. **Production**:
   ```bash
   cp .env.production.example .env.production
   # Edit .env.production with production settings
   # Store secrets in secret manager (AWS Secrets Manager, etc.)
   export ENVIRONMENT=production
   ```

## Docker Compose Files

| File | Purpose | Environment |
|------|---------|-------------|
| `docker-compose.dev.yml` | Local development | Development |
| `docker-compose.test.yml` | Test environment | Test |
| `docker-compose.yml` | (Legacy) | Development |

### Usage

```bash
# Development
docker-compose -f infrastructure/docker/docker-compose.dev.yml up -d

# Test
docker-compose -f infrastructure/docker/docker-compose.test.yml up -d
```

## Feature Flags

Feature flags are controlled via environment variables:

| Flag | Development | Test | Production |
|------|-------------|------|------------|
| `USE_MOCK_APIS` | `true` | `true` | `false` |
| `SEED_MOCK_DATA` | `true` | `true` | `false` |
| `DEBUG` | `true` | `false` | `false` |

## Mock Data Seeding

Mock data is **automatically seeded** in development and test environments, but **blocked** in production:

```bash
# Development/Test - works
ENVIRONMENT=development python scripts/seed-mock-data.py

# Production - blocked for safety
ENVIRONMENT=production python scripts/seed-mock-data.py
# ❌ ERROR: Cannot seed mock data in production environment!
```

## Kubernetes Configuration

In Kubernetes, environment configuration is managed via:

1. **ConfigMaps**: Non-sensitive configuration
   ```yaml
   # infrastructure/kubernetes/base/configmap.yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: cloudsound-config
   data:
     ENVIRONMENT: "production"
     LOG_LEVEL: "INFO"
   ```

2. **Secrets**: Sensitive data (passwords, API keys)
   ```yaml
   # infrastructure/kubernetes/base/secrets.yaml (NOT committed)
   apiVersion: v1
   kind: Secret
   metadata:
     name: cloudsound-secrets
   type: Opaque
   data:
     POSTGRES_PASSWORD: <base64-encoded>
     SECRET_KEY: <base64-encoded>
   ```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
env:
  ENVIRONMENT: ${{ github.ref == 'refs/heads/main' && 'production' || 'test' }}

steps:
  - name: Deploy
    env:
      POSTGRES_PASSWORD: ${{ secrets.POSTGRES_PASSWORD }}
      SECRET_KEY: ${{ secrets.SECRET_KEY }}
    run: |
      kubectl apply -f infrastructure/kubernetes/
```

## Git Branch Strategy

**Branches are for CODE, not for configuration:**

- `main`: Production-ready code
- `develop`: Development branch
- `feature/*`: Feature branches
- `release/*`: Release preparation

**Configuration is environment-based, not branch-based.**

## Security Considerations

1. **Never commit secrets** to Git
2. **Use secret managers** in production (AWS Secrets Manager, HashiCorp Vault)
3. **Rotate secrets regularly**
4. **Use different credentials** for each environment
5. **Enable audit logging** in production

## Troubleshooting

### Wrong environment detected?

```bash
# Check current environment
echo $ENVIRONMENT

# Set explicitly
export ENVIRONMENT=development
```

### Mock APIs not working?

```bash
# Check feature flag
grep USE_MOCK_APIS .env.development

# Should be: USE_MOCK_APIS=true
```

### Can't seed data?

```bash
# Check environment
echo $ENVIRONMENT

# Check flag
grep SEED_MOCK_DATA .env.development

# Should be: SEED_MOCK_DATA=true
```

