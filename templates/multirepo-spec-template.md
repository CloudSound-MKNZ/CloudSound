# Feature Specification: [FEATURE NAME] (Multi-Repo)

**Feature ID**: `[###-feature-name]`  
**Created**: [DATE]  
**Status**: Draft  
**Input**: [User description or ticket reference]

---

## Overview

[Brief description of the feature and its business value]

## Affected Services

<!-- Mark which services will be modified for this feature -->

| Service | Changes | Priority |
|---------|---------|----------|
| cloudsound-shared | [ ] Yes / [ ] No | - |
| cloudsound-radio-streaming | [ ] Yes / [ ] No | - |
| cloudsound-concert-management | [ ] Yes / [ ] No | - |
| cloudsound-authentication | [ ] Yes / [ ] No | - |
| cloudsound-analytics | [ ] Yes / [ ] No | - |
| cloudsound-admin-management | [ ] Yes / [ ] No | - |
| cloudsound-api-gateway | [ ] Yes / [ ] No | - |
| cloudsound-event-manager | [ ] Yes / [ ] No | - |
| cloudsound-music-discovery | [ ] Yes / [ ] No | - |
| Frontend (in CloudSound) | [ ] Yes / [ ] No | - |
| Infrastructure | [ ] Yes / [ ] No | - |

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value]

**Services Involved**: `@service1`, `@service2`, ...

**Independent Test**: [How to test this story works on its own]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey]

**Why this priority**: [Explain the value]

**Services Involved**: `@service1`, `@service2`, ...

**Independent Test**: [How to test independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### Edge Cases

- What happens when [service A is down]?
- How does [service B] handle [invalid data from service A]?
- What happens during [network partition]?

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: [Service] MUST [capability]
- **FR-002**: [Service] MUST [capability]
- **FR-003**: [Service] MUST communicate with [other service] via [method]

### API Changes

<!-- Document any new or modified APIs -->

#### New Endpoints

| Service | Method | Endpoint | Description |
|---------|--------|----------|-------------|
| radio-streaming | GET | `/api/v1/...` | ... |
| concert-management | POST | `/api/v1/...` | ... |

#### Modified Endpoints

| Service | Endpoint | Change |
|---------|----------|--------|
| ... | ... | ... |

### Event/Message Changes

<!-- Document any new Kafka topics or RabbitMQ queues -->

| Type | Topic/Queue | Producer | Consumer | Payload |
|------|-------------|----------|----------|---------|
| Kafka | `topic.name` | @service1 | @service2 | {...} |
| RabbitMQ | `queue.name` | @service1 | @service2 | {...} |

### Database Changes

<!-- Document any schema changes per service -->

| Service | Table | Change | Migration Required |
|---------|-------|--------|-------------------|
| radio-streaming | tracks | Add column `playlist_id` | Yes |
| ... | ... | ... | ... |

### Key Entities

- **[Entity 1]**: [What it represents, which service owns it]
- **[Entity 2]**: [What it represents, relationships]

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: [Measurable metric]
- **SC-002**: [Performance requirement]
- **SC-003**: [User satisfaction metric]

---

## Technical Considerations

### Inter-Service Communication

```
[Service A] --HTTP--> [Service B]
[Service A] --Kafka--> [Service C]
[Service B] --gRPC--> [Service D]
```

### Data Flow

1. User triggers action via Frontend
2. Request hits API Gateway
3. Gateway routes to [Service]
4. [Service] publishes event to Kafka
5. [Other Service] consumes event
6. Response flows back

### Rollout Strategy

<!-- How will this be deployed across services? -->

1. Deploy @shared changes first
2. Deploy backend services (order: ...)
3. Deploy gateway updates
4. Deploy frontend changes
5. Enable feature flag (if applicable)

### Rollback Plan

If issues occur:
1. Disable feature flag
2. Rollback [specific service]
3. ...

---

## Dependencies

### External Dependencies

- [External API or service]
- [Third-party library]

### Internal Dependencies

- Requires [other feature] to be complete
- Depends on [shared code] version X.Y.Z

---

## Out of Scope

- [What this feature explicitly does NOT include]
- [Future enhancements to consider later]

---

## Open Questions

- [ ] [Question needing clarification]
- [ ] [Decision to be made]

---

## References

- Related specs: [link to other specs]
- Design docs: [link]
- API docs: [link]

