# Tasks: [FEATURE NAME] (Multi-Repo)

**Input**: Design documents from `/specs/[###-feature-name]/`  
**Architecture**: Multi-repo microservices  
**Prerequisites**: plan.md (required), spec.md (required for user stories)

---

## Multi-Repo Development Guide

### Repository Structure

| Repository | Purpose | Port |
|------------|---------|------|
| `cloudsound-shared` | Shared Python package | N/A |
| `cloudsound-radio-streaming` | Radio streaming service | 8004 |
| `cloudsound-concert-management` | Concert management | 8005 |
| `cloudsound-authentication` | Auth service | 8001 |
| `cloudsound-analytics` | Analytics service | 8007 |
| `cloudsound-admin-management` | Admin management | 8006 |
| `cloudsound-api-gateway` | API Gateway | 8000 |
| `cloudsound-event-manager` | Event manager | 8003 |
| `cloudsound-music-discovery` | Music discovery | 8002 |
| `CloudSound` | Infrastructure & Specs | N/A |

### Task Format

```
[ID] [P?] [Story] [@repo] Description
```

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story reference (US1, US2, etc.)
- **[@repo]**: Target repository for the change
  - `@shared` - cloudsound-shared
  - `@radio` - cloudsound-radio-streaming
  - `@concerts` - cloudsound-concert-management
  - `@auth` - cloudsound-authentication
  - `@analytics` - cloudsound-analytics
  - `@admin` - cloudsound-admin-management
  - `@gateway` - cloudsound-api-gateway
  - `@events` - cloudsound-event-manager
  - `@discovery` - cloudsound-music-discovery
  - `@infra` - CloudSound (infrastructure repo)
  - `@frontend` - Frontend (if separated)

### Workflow

1. **Check out feature branch** in each affected repo
2. **Commit changes** to each repo separately
3. **Update shared package version** if shared code changes
4. **Update task status** in this file (CloudSound/specs/)
5. **Create PRs** in each affected repo

---

## Phase 1: Planning & Shared Code

**Purpose**: Update shared utilities and plan cross-repo changes

- [ ] T001 [@infra] Create feature specification in specs/[###-feature-name]/
- [ ] T002 [@infra] Update tasks.md with implementation plan
- [ ] T003 [P] [@shared] Add shared utilities/models if needed in cloudsound_shared/
- [ ] T004 [@shared] Bump version in setup.py (if shared code changed)

**Checkpoint**: Shared code ready, feature branches created

---

## Phase 2: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description]  
**Affected Repos**: [@repo1, @repo2, ...]  
**Independent Test**: [How to verify]

### Backend Changes

- [ ] T010 [P] [US1] [@radio] Create model in src/models/
- [ ] T011 [P] [US1] [@concerts] Create model in src/models/
- [ ] T012 [US1] [@radio] Implement service in src/services/
- [ ] T013 [US1] [@radio] Implement API endpoint in src/api/
- [ ] T014 [US1] [@analytics] Add event consumer in src/consumers/

### Frontend Changes

- [ ] T015 [US1] [@infra] Create component in frontend/src/lib/components/
- [ ] T016 [US1] [@infra] Create route in frontend/src/routes/

### Infrastructure Changes

- [ ] T017 [P] [US1] [@infra] Update Kubernetes manifest in infrastructure/kubernetes/
- [ ] T018 [P] [US1] [@infra] Update Helm values in infrastructure/helm/

**Checkpoint**: User Story 1 complete - test independently before proceeding

---

## Phase 3: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description]  
**Affected Repos**: [@repo1, @repo2, ...]  
**Independent Test**: [How to verify]

### Backend Changes

- [ ] T020 [P] [US2] [@repo] Create model in src/models/
- [ ] T021 [US2] [@repo] Implement service in src/services/
- [ ] T022 [US2] [@repo] Implement API endpoint in src/api/

### Frontend Changes

- [ ] T023 [US2] [@infra] Create component in frontend/src/lib/components/

**Checkpoint**: User Story 2 complete

---

## Phase N: Integration & Cross-Cutting

**Purpose**: Connect services, update infrastructure

- [ ] TXXX [@gateway] Update API Gateway routes
- [ ] TXXX [@infra] Update docker-compose.services.yml
- [ ] TXXX [@infra] Update Kubernetes deployments
- [ ] TXXX [@infra] Update documentation in docs/

---

## Dependencies & Commit Order

### Cross-Repo Dependencies

When changes span multiple repos, commit in this order:

1. **@shared** first (if shared code changes)
2. **Backend services** (can be parallel if independent)
3. **@gateway** (after backend services)
4. **@infra** (frontend, kubernetes, docs)

### Shared Package Updates

If you modify `cloudsound-shared`:

```bash
# 1. Make changes in cloudsound-shared
cd cloudsound-shared
git commit -m "feat: add new utility"
git tag v1.x.x
git push origin main --tags

# 2. Update dependent services
cd ../cloudsound-radio-streaming
pip install --upgrade git+https://github.com/CloudSound-MKNZ/cloudsound-shared.git@v1.x.x
pip freeze > requirements.txt
git commit -am "chore: bump cloudsound-shared to v1.x.x"
```

---

## PR Checklist

For each affected repository:

- [ ] Feature branch created from `main`
- [ ] All tests pass
- [ ] Linting passes
- [ ] API documentation updated (if endpoints changed)
- [ ] README updated (if setup changed)
- [ ] PR created with link to spec

### PR Naming Convention

```
feat(service): [US#] Brief description

Example:
feat(radio-streaming): [US5] Add playlist shuffle endpoint
```

---

## Notes

- Update this task list as you complete work
- Each repo has its own CI/CD - ensure all pass before merge
- Test integrations locally using docker-compose.full.yml
- Keep PRs focused - one user story per PR when possible

