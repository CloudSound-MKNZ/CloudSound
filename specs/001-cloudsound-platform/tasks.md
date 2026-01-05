# Tasks: CloudSound Radio Platform

**Input**: Design documents from `/specs/001-cloudsound-platform/`  
**Architecture**: Multi-repo microservices  
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] [@repo] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **[@repo]**: Target repository for the change
- Include exact file paths in descriptions

### Repository Key

| Tag | Repository | Description |
|-----|------------|-------------|
| `@shared` | cloudsound-shared | Shared Python package |
| `@radio` | cloudsound-radio-streaming | Radio streaming service |
| `@concerts` | cloudsound-concert-management | Concert management |
| `@auth` | cloudsound-authentication | Authentication service |
| `@analytics` | cloudsound-analytics | Analytics service |
| `@admin` | cloudsound-admin-management | Admin management |
| `@gateway` | cloudsound-api-gateway | API Gateway |
| `@events` | cloudsound-event-manager | Event manager |
| `@discovery` | cloudsound-music-discovery | Music discovery |
| `@infra` | CloudSound | Infrastructure, frontend, specs |

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 [@infra] Create project root directory structure (frontend/, backend/, infrastructure/, scripts/)
- [x] T002 [P] [@infra] Initialize frontend service structure in frontend/ with SvelteKit
- [x] T003 [P] [@all-services] Initialize backend service directories (api-gateway/, concert-management/, event-manager/, music-discovery/, radio-streaming/, admin-management/, authentication/)
- [x] T004 [P] [@infra] Create infrastructure directory structure (kubernetes/, helm/, docker/)
- [x] T005 [P] [@all-services] Setup Python virtual environments and requirements.txt templates for each backend service
- [x] T006 [P] [@all-services] Configure linting tools (ruff, black) for Python services
- [x] T007 [P] [@infra] Configure ESLint and Prettier for SvelteKit frontend
- [x] T008 [@infra] Create Docker Compose file for local development infrastructure in infrastructure/docker/docker-compose.yml
- [x] T009 [@all-repos] Create .gitignore files for Python and Node.js projects
- [x] T010 [@all-repos] Create README.md files for each service directory
- [x] **T011-MR** [@all-repos] Migrate from monorepo to multi-repo structure (9 separate repositories)
- [x] **T012-MR** [@infra] Update infrastructure configs for multi-repo (Docker Compose, Kubernetes, Helm)
- [x] **T013-MR** [@all-services] Set up CI/CD workflows for all services (GitHub Actions)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

**Note**: Mock data and API clients are provided for development. See `scripts/seed-mock-data.py` and `backend/shared/clients/mock_apis.py`.

- [x] T011 [@shared] Setup PostgreSQL database schema and migrations framework using Alembic in db/
- [x] T012 [@shared] Create database connection pool configuration in db/pool.py
- [x] T013 [P] [@shared] Implement base database models (Base class) in models/base.py
- [x] T014 [P] [@auth] Create authentication service structure
- [x] T015 [P] [@auth] Implement JWT token generation and validation in src/jwt_handler.py
- [x] T016 [P] [@auth] Create authentication API endpoints in src/api/auth.py
- [x] T017 [P] [@shared] Setup Kafka cluster configuration and connection utilities in kafka/
- [x] T018 [P] [@shared] Setup RabbitMQ connection utilities in rabbitmq/
- [x] T019 [P] [@shared] Configure MinIO/S3 client utilities in storage/
- [x] T020 [P] [@shared] Create shared logging configuration (structlog) in logging/
- [x] T021 [P] [@shared] Create shared Prometheus metrics utilities in metrics/
- [x] T022 [P] [@shared] Create health check endpoint template in health/
- [x] T023 [P] [@shared] Create error handling middleware in middleware/
- [x] T024 [P] [@shared] Setup environment configuration management (pydantic-settings) in config/
- [x] T025 [@shared] Create database migration for AdminUser table in db/migrations/
- [x] T026 [P] [@shared] Create correlation ID middleware for request tracing in middleware/correlation.py
- [x] T027 [@infra] Create Kubernetes namespace and base configurations in infrastructure/kubernetes/base/

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View and Listen to Radio Stations (Priority: P1) 🎯 MVP

**Goal**: Users can browse and listen to different radio stations organized by upcoming concerts, past performers, and music genres with smooth crossfade transitions.

**Independent Test**: A user can open the application, select a radio station (e.g., "Upcoming Bands"), and hear music streaming with smooth transitions. This can be tested independently without any admin functionality.

### Implementation for User Story 1

- [x] T028 [P] [US1] [@radio] Create Artist model in src/models/artist.py
- [x] T029 [P] [US1] [@radio] Create Track model in src/models/track.py
- [x] T030 [P] [US1] [@radio] Create RadioStation model in src/models/radio_station.py
- [x] T031 [P] [US1] [@radio] Create StationTrack junction model in src/models/station_track.py
- [x] T032 [P] [US1] [@analytics] Create PlaybackEvent model in src/models/playback_event.py
- [x] T033 [US1] [@shared] Create database migration for Artist, Track, RadioStation, StationTrack, PlaybackEvent tables in db/migrations/
- [x] T034 [US1] [@radio] Implement RadioStationService for managing stations in src/services/station_service.py
- [x] T035 [US1] [@radio] Implement TrackService for managing tracks in src/services/track_service.py
- [x] T036 [US1] [@analytics] Implement PlaybackEventService for tracking playback statistics in src/services/playback_service.py
- [x] T037 [US1] [@radio] Implement audio streaming endpoint with HTTP range requests in src/api/streaming.py
- [x] T038 [US1] [@radio] Implement playback event tracking in streaming endpoint in src/api/streaming.py
- [x] T039 [US1] [@radio] Implement radio station list endpoint in src/api/stations.py
- [x] T040 [US1] [@radio] Implement station stream endpoint in src/api/stations.py
- [x] T041 [US1] [@infra] Create frontend radio station browser component in frontend/src/lib/components/RadioStationBrowser.svelte
- [x] T042 [US1] [@infra] Create frontend audio player component with crossfade in frontend/src/lib/components/AudioPlayer.svelte
- [x] T043 [US1] [@infra] Implement crossfade logic in frontend/src/lib/utils/crossfade.ts
- [x] T044 [US1] [@infra] Create radio station route in frontend/src/routes/radio/+page.svelte
- [x] T045 [US1] [@radio] Implement Kafka producer for radio.playback.events topic in src/producers/kafka_producer.py
- [x] T046 [US1] [@analytics] Implement Kafka consumer for playback events in src/consumers/playback_consumer.py
- [x] T047 [US1] [@radio] Add Prometheus metrics for streaming requests in src/metrics.py
- [x] T048 [US1] [@radio] Add structured logging for streaming operations in src/main.py
- [x] T049 [US1] [@radio] Create Dockerfile in Dockerfile
- [x] T050 [US1] [@analytics] Create Dockerfile in Dockerfile
- [x] T051 [US1] [@infra] Create Kubernetes deployment manifest in infrastructure/kubernetes/radio-streaming/deployment.yaml
- [x] T052 [US1] [@infra] Create Kubernetes service manifest in infrastructure/kubernetes/radio-streaming/service.yaml
- [x] T053 [US1] [@infra] Create Kubernetes deployment manifest for analytics service in infrastructure/kubernetes/analytics/deployment.yaml

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. Users can browse and listen to radio stations with crossfade transitions.

---

## Phase 4: User Story 2 - Browse Concert Schedule (Priority: P1)

**Goal**: Users can view the concert schedule showing upcoming concerts with dates, locations, and performers.

**Independent Test**: A user can open the application and view a list of upcoming concerts with dates, locations, and performer names. This works independently of radio streaming.

### Implementation for User Story 2

- [x] T054 [P] [US2] [@concerts] Create Concert model with optimistic locking (version field) in src/models/concert.py
- [x] T055 [P] [US2] [@concerts] Create ConcertArtist junction model in src/models/concert_artist.py
- [x] T056 [US2] [@shared] Create database migration for Concert and ConcertArtist tables in db/migrations/
- [x] T057 [US2] [@concerts] Implement ConcertService for managing concerts with conflict detection in src/services/concert_service.py
- [x] T058 [US2] [@concerts] Implement concert list endpoint (GET /api/v1/concerts) in src/api/concerts.py
- [x] T059 [US2] [@concerts] Implement concert detail endpoint (GET /api/v1/concerts/{id}) in src/api/concerts.py
- [x] T060 [US2] [@infra] Create frontend concert schedule component in frontend/src/lib/components/ConcertSchedule.svelte
- [x] T061 [US2] [@infra] Create concert schedule route in frontend/src/routes/concerts/+page.svelte
- [x] T062 [US2] [@concerts] Implement concert sorting by date (chronological) in src/services/concert_service.py
- [x] T063 [US2] [@infra] Add empty state handling in frontend/src/lib/components/ConcertSchedule.svelte
- [x] T064 [US2] [@concerts] Add Prometheus metrics for concert API requests in src/metrics.py
- [x] T065 [US2] [@concerts] Add structured logging for concert operations in src/main.py
- [x] T066 [US2] [@concerts] Create Dockerfile in Dockerfile
- [x] T067 [US2] [@infra] Create Kubernetes deployment manifest in infrastructure/kubernetes/concert-management/deployment.yaml
- [x] T068 [US2] [@infra] Create Kubernetes service manifest in infrastructure/kubernetes/concert-management/service.yaml

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. Users can view concerts and listen to radio stations.

---

## Phase 5: User Story 3 - Search Music (Priority: P2)

**Goal**: Users can search for music by artist name or track title across all available music in the system.

**Independent Test**: A user can search for an artist name or track title and see matching results. This can work independently once music is in the system.

### Implementation for User Story 3

- [x] T069 [US3] Implement search service for artists and tracks in backend/radio-streaming/src/services/search_service.py
- [x] T070 [US3] Create database indexes for search performance on artist.name and track.title in backend/shared/db/migrations/
- [x] T071 [US3] Implement search endpoint (GET /api/v1/search) in backend/radio-streaming/src/api/search.py
- [x] T072 [US3] Create frontend search component in frontend/src/lib/components/SearchBar.svelte
- [x] T073 [US3] Create search results component in frontend/src/lib/components/SearchResults.svelte
- [x] T074 [US3] Create search route in frontend/src/routes/search/+page.svelte
- [x] T075 [US3] Implement "no results" empty state in frontend/src/lib/components/SearchResults.svelte
- [x] T076 [US3] Add search metrics to Prometheus in backend/radio-streaming/src/metrics.py
- [x] T077 [US3] Add search logging in backend/radio-streaming/src/main.py

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should all work independently. Users can search for music, view concerts, and listen to radio stations.

---

## Phase 6: User Story 4 - Admin Concert Management (Priority: P2)

**Goal**: Administrators can create, update, and delete concerts in the schedule. Only administrators can perform these actions.

**Independent Test**: An authenticated admin can create a new concert with date, location, and performers, and it appears in the concert schedule. This can be tested independently with mock authentication.

### Implementation for User Story 4

- [x] T078 [P] [US4] Create AdminUser model in backend/admin-management/src/models/admin_user.py
- [x] T079 [US4] Create database migration for AdminUser table (if not in foundational phase) in backend/shared/db/migrations/
- [x] T080 [US4] Implement admin authentication middleware in backend/api-gateway/src/middleware/auth.py
- [x] T081 [US4] Implement concert create endpoint (POST /api/v1/concerts) with admin auth and optimistic locking in backend/concert-management/src/api/concerts.py
- [x] T082 [US4] Implement concert update endpoint (PUT /api/v1/concerts/{id}) with admin auth and conflict detection in backend/concert-management/src/api/concerts.py
- [x] T083 [US4] Implement concert delete endpoint (DELETE /api/v1/concerts/{id}) with admin auth in backend/concert-management/src/api/concerts.py
- [x] T084 [US4] Create frontend admin login component in frontend/src/lib/components/AdminLogin.svelte
- [x] T085 [US4] Create frontend concert form component in frontend/src/lib/components/ConcertForm.svelte
- [x] T086 [US4] Create admin concert management route in frontend/src/routes/admin/concerts/+page.svelte
- [x] T087 [US4] Implement authorization error handling in frontend/src/lib/stores/auth.js
- [x] T088 [US4] Add admin operation metrics to Prometheus in backend/concert-management/src/metrics.py
- [x] T089 [US4] Add admin operation logging in backend/concert-management/src/main.py
- [x] T090 [US4] Create Dockerfile for admin-management service in backend/admin-management/Dockerfile
- [x] T091 [US4] Create Kubernetes deployment manifest in infrastructure/kubernetes/admin-management/deployment.yaml

**Checkpoint**: At this point, User Stories 1-4 should all work independently. Admins can manage concerts, users can view them and listen to radio.

---

## Phase 7: User Story 5 - Automatic Music Discovery (Priority: P3)

**Goal**: The system automatically discovers and downloads music from YouTube and Bandcamp APIs based on concert information and event descriptions.

**Independent Test**: When a concert is added with a YouTube or Bandcamp link in the description, the system automatically extracts the link, downloads the music, and makes it available for streaming. This can be tested with mock API responses.

### Implementation for User Story 5

- [x] T092 [P] [US5] [@discovery] Create YouTube API client with circuit breaker in src/clients/youtube_client.py
- [x] T093 [P] [US5] [@discovery] Create Bandcamp API client with circuit breaker in src/clients/bandcamp_client.py
- [x] T094 [US5] [@discovery] Implement link extraction service from text in src/services/link_extractor.py
- [x] T095 [US5] [@discovery] Implement music downloader service with storage quota checking in src/services/downloader.py
- [x] T096 [US5] [@discovery] Implement storage quota monitoring and error handling in src/services/storage_service.py
- [x] T097 [US5] [@discovery] Implement Kafka consumer for event processing in src/consumers/kafka_consumer.py
- [x] T098 [US5] [@discovery] Implement RabbitMQ producer for download tasks in src/producers/rabbitmq_producer.py
- [x] T099 [US5] [@discovery] Implement RabbitMQ consumer for download queue in src/consumers/rabbitmq_consumer.py
- [x] T100 [US5] [@discovery] Implement circuit breaker for external API calls in src/utils/circuit_breaker.py
- [x] T101 [US5] [@discovery] Implement retry logic with exponential backoff in src/utils/retry.py
- [x] T102 [US5] [@discovery] Create music storage service for MinIO/S3 in src/services/storage_service.py
- [x] T103 [US5] [@discovery] Implement Kafka producer for music.downloaded events in src/producers/kafka_producer.py
- [x] T104 [US5] [@discovery] Add music discovery metrics to Prometheus in src/metrics.py
- [x] T105 [US5] [@discovery] Add music discovery logging in src/main.py
- [x] T106 [US5] [@discovery] Create Dockerfile in Dockerfile
- [x] T107 [US5] [@infra] Create Kubernetes deployment manifest in infrastructure/kubernetes/music-discovery/deployment.yaml
- [x] T108 [US5] [@infra] Create Kubernetes service manifest in infrastructure/kubernetes/music-discovery/service.yaml

**Checkpoint**: At this point, User Story 5 should work independently. Music is automatically discovered and downloaded when concerts are created with music links.

---

## Phase 8: User Story 6 - Facebook Events Integration (Priority: P3)

**Goal**: The system automatically fetches events from Facebook Events API and links them to the concert schedule.

**Independent Test**: The system periodically checks Facebook Events API, finds events matching concert dates, and automatically creates or links them to the schedule. This can be tested with mock Facebook API responses.

### Implementation for User Story 6

- [x] T109 [P] [US6] [@events] Create Facebook Events API client with circuit breaker in src/clients/facebook_client.py (PLACEHOLDER - mock implementation)
- [x] T110 [US6] [@events] Implement event parser service with malformed data handling in src/services/event_parser.py
- [x] T111 [US6] [@events] Implement scheduled job for Facebook API polling in src/jobs/facebook_poller.py
- [x] T112 [US6] [@events] Implement Kafka producer for facebook.events.raw topic in src/producers/kafka_producer.py
- [x] T113 [US6] [@events] Implement event enrichment service in src/services/enrichment_service.py
- [x] T114 [US6] [@events] Implement event linking service to concerts in src/services/linking_service.py
- [x] T115 [US6] [@events] Implement Kafka consumer for event processing pipeline in src/consumers/kafka_consumer.py
- [x] T116 [US6] [@events] Add circuit breaker for Facebook API calls in src/utils/circuit_breaker.py
- [x] T117 [US6] [@events] Add retry logic for Facebook API in src/utils/retry.py
- [x] T118 [US6] [@events] Add Facebook integration metrics to Prometheus in src/metrics.py
- [x] T119 [US6] [@events] Add Facebook integration logging in src/main.py
- [x] T120 [US6] [@events] Create Dockerfile in Dockerfile
- [x] T121 [US6] [@infra] Create Kubernetes deployment manifest in infrastructure/kubernetes/event-manager/deployment.yaml
- [x] T122 [US6] [@infra] Create Kubernetes CronJob for Facebook polling in infrastructure/kubernetes/event-manager/cronjob.yaml

**Checkpoint**: At this point, User Story 6 should work independently. Facebook events are automatically fetched and linked to concerts.

---

## Phase 9: Integration & API Gateway

**Purpose**: Connect all services through API Gateway and enable end-to-end functionality

- [x] T123 [@gateway] Create API Gateway service structure
- [x] T124 [@gateway] Implement API Gateway routing with versioning (/api/v1/) in src/routes/gateway.py
- [x] T125 [@gateway] Implement request forwarding to backend services in src/middleware/proxy.py
- [x] T126 [@gateway] Implement authentication middleware in src/middleware/auth.py
- [x] T127 [@gateway] Implement rate limiting in src/middleware/rate_limit.py
- [ ] T128 [P] [@infra] Create gRPC proto files for event synchronization in contracts/grpc/event_sync.proto (OPTIONAL)
- [ ] T129 [P] [@infra] Create gRPC proto files for music metadata updates in contracts/grpc/music_metadata.proto (OPTIONAL)
- [ ] T130 [P] [@infra] Create gRPC proto files for playback events in contracts/grpc/playback_events.proto (OPTIONAL)
- [ ] T131 [@concerts] Implement gRPC server in src/grpc/server.py (OPTIONAL)
- [ ] T132 [@events] Implement gRPC client in src/grpc/client.py (OPTIONAL)
- [ ] T133 [@discovery] Implement gRPC server in src/grpc/server.py (OPTIONAL)
- [ ] T134 [@radio] Implement gRPC client in src/grpc/client.py (OPTIONAL)
- [ ] T135 [@analytics] Implement gRPC server for playback events in src/grpc/server.py (OPTIONAL)
- [x] T136 [@gateway] Create Dockerfile in Dockerfile
- [x] T137 [@infra] Create Kubernetes deployment manifest in infrastructure/kubernetes/api-gateway/deployment.yaml
- [x] T138 [@infra] Create Kubernetes service manifest in infrastructure/kubernetes/api-gateway/service.yaml
- [x] T139 [@infra] Create Ingress configuration for API Gateway in infrastructure/kubernetes/api-gateway/ingress.yaml
- [x] T140 [@infra] Update frontend to use API Gateway endpoints in frontend/src/lib/api/client.ts

---

## Phase 10: Observability

**Purpose**: Implement comprehensive monitoring, logging, and metrics

- [x] T141 [P] [@infra] Setup Prometheus server configuration in infrastructure/kubernetes/prometheus/
- [x] T142 [P] [@infra] Setup Grafana with dashboards in infrastructure/kubernetes/grafana/
- [x] T143 [P] [@infra] Setup Loki for centralized logging in infrastructure/kubernetes/loki/
- [x] T144 [P] [@infra] Create Prometheus ServiceMonitor for all services in infrastructure/kubernetes/prometheus/
- [x] T145 [P] [@infra] Create Grafana dashboards for each service in infrastructure/kubernetes/grafana/dashboards/
- [x] T146 [P] [@infra] Configure log aggregation (Promtail) for all services in infrastructure/kubernetes/loki/
- [x] T147 [@infra] Create alerting rules in infrastructure/kubernetes/prometheus/alerts.yaml

---

## Phase 11: Kubernetes & Helm

**Purpose**: Package and deploy all services to Kubernetes

- [x] T148 [@infra] Create Helm Chart structure in infrastructure/helm/cloudsound/
- [x] T149 [@infra] Create Chart.yaml with dependencies in infrastructure/helm/cloudsound/Chart.yaml
- [x] T150 [@infra] Create values.yaml with environment configurations in infrastructure/helm/cloudsound/values.yaml
- [x] T151 [P] [@infra] Create Helm templates for all services in infrastructure/helm/cloudsound/templates/
- [x] T152 [@infra] Create Helm templates for infrastructure (Kafka, RabbitMQ, PostgreSQL) in infrastructure/helm/cloudsound/templates/
- [x] T153 [@all-services] Create CI/CD pipeline configuration in .github/workflows/deploy.yml
- [ ] T154 [@infra] Test Helm chart installation locally
- [ ] T155 [@infra] Deploy to staging Kubernetes cluster

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T156 [P] [@all-services] Add comprehensive error handling across all services
- [ ] T157 [P] [@all-services] Implement request validation with Pydantic in all API endpoints
- [ ] T158 [P] [@gateway] Generate OpenAPI/Swagger documentation in docs/openapi.yaml
- [ ] T159 [P] [@concerts] Generate OpenAPI/Swagger documentation in docs/openapi.yaml
- [ ] T160 [P] [@radio] Generate OpenAPI/Swagger documentation in docs/openapi.yaml
- [ ] T161 [P] [@discovery] Generate OpenAPI/Swagger documentation in docs/openapi.yaml
- [ ] T162 [P] [@events] Generate OpenAPI/Swagger documentation in docs/openapi.yaml
- [ ] T163 [P] [@admin] Generate OpenAPI/Swagger documentation in docs/openapi.yaml
- [ ] T164 [P] [@auth] Generate OpenAPI/Swagger documentation in docs/openapi.yaml
- [ ] T165 [P] [@gateway] Setup Swagger UI for API documentation in src/api/docs.py
- [ ] T166 [P] [@shared] Optimize database queries with proper indexing
- [ ] T167 [P] [@all-services] Add caching layer for frequently accessed data (Redis optional)
- [ ] T168 [P] [@all-services] Implement graceful shutdown handlers
- [ ] T169 [P] [@all-services] Add comprehensive logging for all critical operations
- [ ] T170 [P] [@all-services] Performance testing and optimization
- [ ] T171 [P] [@all-services] Security audit and hardening
- [ ] T172 [@infra] Create deployment documentation in docs/deployment.md
- [ ] T173 [@infra] Create developer setup guide in docs/development.md
- [ ] T174 [@infra] Run end-to-end validation using quickstart.md scenarios

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - User stories can proceed in parallel (if staffed) or sequentially in priority order
- **Integration (Phase 9)**: Depends on all user stories being complete
- **Observability (Phase 10)**: Can be implemented in parallel with user stories
- **Kubernetes & Helm (Phase 11)**: Depends on all services being implemented
- **Polish (Phase 12)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational - Independent of US1
- **User Story 3 (P2)**: Can start after Foundational - Depends on US1 (needs tracks/artists)
- **User Story 4 (P2)**: Can start after Foundational - Depends on US2 (needs concerts)
- **User Story 5 (P3)**: Can start after Foundational - Depends on US1 and US2 (needs tracks and concerts)
- **User Story 6 (P3)**: Can start after Foundational - Depends on US2 (needs concerts)

### Within Each User Story

- Models before services
- Services before endpoints
- Backend before frontend
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, User Stories 1 and 2 can start in parallel
- Models within a story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members
- Observability setup can run in parallel with user story implementation

---

## Parallel Example: User Story 1

```bash
# Launch all models for User Story 1 together:
Task: "Create Artist model in backend/radio-streaming/src/models/artist.py"
Task: "Create Track model in backend/radio-streaming/src/models/track.py"
Task: "Create RadioStation model in backend/radio-streaming/src/models/radio_station.py"
Task: "Create StationTrack junction model in backend/radio-streaming/src/models/station_track.py"
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Radio Streaming)
4. Complete Phase 4: User Story 2 (Concert Schedule)
5. **STOP and VALIDATE**: Test User Stories 1 & 2 independently
6. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo
3. Add User Story 2 → Test independently → Deploy/Demo (MVP!)
4. Add User Story 3 → Test independently → Deploy/Demo
5. Add User Story 4 → Test independently → Deploy/Demo
6. Add User Story 5 → Test independently → Deploy/Demo
7. Add User Story 6 → Test independently → Deploy/Demo
8. Each story adds value without breaking previous stories

### Parallel Team Strategy

With two developers:

1. Both complete Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Radio Streaming)
   - Developer B: User Story 2 (Concert Schedule)
3. After US1 and US2 complete:
   - Developer A: User Story 3 (Search) + User Story 5 (Music Discovery)
   - Developer B: User Story 4 (Admin) + User Story 6 (Facebook Integration)
4. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- [@repo] label maps task to specific repository
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- Total tasks: 174
- Estimated MVP (Phases 1-4): ~70 tasks
- Estimated Full Implementation: 174 tasks

---

## Multi-Repo Development Workflow

### Setting Up Your Workspace

1. **Clone all repos** as siblings:
   ```bash
   mkdir ~/CloudSound-Workspace && cd ~/CloudSound-Workspace
   git clone git@github.com:CloudSound-MKNZ/CloudSound.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-shared.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-radio-streaming.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-concert-management.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-authentication.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-analytics.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-admin-management.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-api-gateway.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-event-manager.git
   git clone git@github.com:CloudSound-MKNZ/cloudsound-music-discovery.git
   ```

2. **Open multi-root workspace** in Cursor:
   ```bash
   cursor CloudSound/cloudsound.code-workspace
   ```

### Working on a Task

1. **Identify the repo** from the `[@repo]` tag
2. **Create feature branch** in that repo:
   ```bash
   cd cloudsound-radio-streaming
   git checkout -b feature/US5-playlist-shuffle
   ```
3. **Make changes and commit**
4. **Update task status** in CloudSound/specs/001-cloudsound-platform/tasks.md
5. **Create PR** in the service repo

### Cross-Repo Changes

When a task affects multiple repos:

1. Start with `@shared` if shared code changes
2. Bump version and push `@shared`
3. Update services to use new shared version
4. Make service-specific changes
5. Update infrastructure last

### Running Locally

```bash
# From CloudSound repo
cd CloudSound

# Start infrastructure
docker compose -f infrastructure/docker/docker-compose.dev.yml up -d

# Start all services (requires repos as siblings)
docker compose -f infrastructure/docker/docker-compose.services.yml up -d
```

### PR Checklist

For each affected repo:
- [ ] Feature branch from `main`
- [ ] Tests pass
- [ ] Linting passes
- [ ] README updated if needed
- [ ] PR links to spec/task

