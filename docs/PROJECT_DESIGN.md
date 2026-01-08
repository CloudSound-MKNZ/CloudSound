# CloudSound - Radio Platform for Local Music Club

## Project Information

- **Project Title**: Radio Platform for Local Music Club
- **Team Members**: Tevž Sedmak and Matjaž Kumin
- **Project Group Number**: 23
- **Group Name**: CloudSound

## Project Description

The goal of this project is to develop a web ap
plication that enables a local music club to manage concert schedules while simultaneously offering users the ability to listen to music through an integrated radio. The application will automatically fetch music from YouTube and Bandcamp APIs and enable listening to different radio stations organized by genres, past performers, and upcoming concerts.

## Technology Stack

### Backend
- **Language**: Python 3.11+
- **Framework**: FastAPI (primary), Flask (if needed for specific services)
- **Database**: PostgreSQL 15+
- **Message Broker - Event Streaming**: Apache Kafka
- **Message Broker - Task Queues**: RabbitMQ
- **Authentication**: JWT (JSON Web Tokens)
- **Communication**: REST API + gRPC

### Frontend
- **Framework**: SvelteKit
- **Deployment**: Standalone service (nginx container serving static files)

### Infrastructure
- **Containerization**: Docker
- **Orchestration**: Kubernetes (k3s)
- **API Gateway**: Kong / Istio / AWS API Gateway
- **Load Balancer**: HAProxy / NGINX Ingress Controller

### Storage
- **Object Storage**: MinIO / S3 for MP3 files
- **Database Storage**: Persistent volumes for PostgreSQL

### External APIs
- **YouTube API**: Music fetching
- **Bandcamp API**: Additional music source
- **Facebook Events API**: Automatic event discovery

### Observability
- **Metrics**: Prometheus
- **Visualization**: Grafana
- **Logging**: ELK Stack (Elasticsearch, Logstash, Kibana) or Loki
- **Health Checks**: Kubernetes-native health endpoints

### Additional Features
- **Crossfade and smooth transitions** between tracks
- **Playback history tracking** for statistics

## Architecture Overview

### Microservices Architecture

The system is divided into the following microservices:

1. **Frontend Service** (Svelte)
   - Serves static Svelte application
   - Communicates with backend via API Gateway
   - Independent deployment and scaling

2. **API Gateway Service**
   - Centralized entry point for all API requests
   - Authentication and authorization
   - Request routing and load balancing

3. **Concert Management Service**
   - Manages concert schedules
   - CRUD operations for concerts
   - Integrates with Facebook Events API

4. **Event Manager Service**
   - Fetches events from Facebook Events API
   - Parses event descriptions
   - Publishes events to Kafka topics

5. **Music Discovery Service**
   - Extracts music links from event descriptions
   - Downloads music from YouTube/Bandcamp APIs
   - Manages music metadata

6. **Radio Streaming Service**
   - Manages radio stations (by genre, upcoming, past performers)
   - Handles audio streaming
   - Implements crossfade and transitions

7. **Admin Management Service**
   - Admin registration and authentication
   - Admin profile management
   - Radio usage statistics (aggregated, not per-user)

8. **Authentication Service**
   - JWT token generation and validation
   - User session management

9. **Analytics Service** (optional)
   - Aggregates playback statistics
   - Generates reports

### Communication Patterns

#### Event-Driven Architecture (Kafka)
- **Topic: `facebook.events.raw`** - Raw events from Facebook API
- **Topic: `facebook.events.parsed`** - Parsed events with extracted data
- **Topic: `facebook.events.enriched`** - Events with music links extracted
- **Topic: `music.discovery.requests`** - Music discovery requests
- **Topic: `music.downloaded`** - Notifications when music is downloaded
- **Topic: `radio.playback.events`** - Playback events for statistics

#### Message Queues (RabbitMQ)
- **Queue: `music.download.queue`** - MP3 download tasks (with ACK)
- **Queue: `music.process.queue`** - Music processing tasks
- **Queue: `event.sync.queue`** - Event synchronization tasks

#### Synchronous Communication
- REST API for frontend-backend communication
- gRPC for inter-service communication (where low latency is critical)

### Data Flow

```
Facebook Events API
    ↓
Event Manager Service
    ↓ (publishes to Kafka)
Kafka Topics
    ↓ (consumed by)
Concert Management Service
Music Discovery Service
    ↓ (publishes download tasks to)
RabbitMQ
    ↓ (processed by)
Music Download Workers
    ↓ (stores in)
MinIO/S3
    ↓ (metadata in)
PostgreSQL
    ↓ (served by)
Radio Streaming Service
    ↓ (streamed to)
Frontend Service
```

## Use Cases

### Basic User Use Cases

1. **View Upcoming Concerts** - User views the concert schedule
2. **Listen to "Upcoming Bands" Radio** - User listens to music from upcoming performers
3. **Listen to "Past Bands" Radio** - User listens to music from past performers
4. **Listen to Radio by Genre** - User selects a genre (rock, jazz, metal) and listens to corresponding music
5. **Search Music** - User searches for music by artist name or track title
6. **View Playback History** - User views what they have listened to

### Admin Use Cases

7. **Admin Registration** - Only administrators can register
8. **Add Concert** - Admin adds a new concert with date, location, and performers
9. **Edit Concert** - Admin updates concert information
10. **Delete Concert** - Admin removes a concert from the schedule
11. **Manage Season** - Admin plans concerts for the upcoming season
12. **Facebook Integration** - System automatically links Facebook events to the schedule

### Complex Use Case: End-to-End Flow

**"Complete process from season planning to user radio listening"**

1. **Admin plans season** - Admin pre-writes concerts for the season in admin interface with dates, locations, and performers
2. **Concert Management Service stores concerts** in database
3. **Facebook Events API integration** - System automatically checks Facebook Events API for events on specific dates
4. **Automatic linking** - When a Facebook event is created, system automatically links it to the schedule
5. **Music Discovery Service reads YouTube/Bandcamp links** from event description and finds artist music
6. **Automatic downloading** - System downloads MP3 files from YouTube/Bandcamp APIs
7. **Storage and organization** - MP3 files are stored on server and organized by artists/genres
8. **Radio Streaming Service updates radio station** "Upcoming Bands" with new music
9. **User opens application** and selects radio station "Upcoming Bands"
10. **Real-time streaming** - System starts playing music from the artist who will perform
11. **Playback tracking** - System records what user listened to for statistics
12. **Crossfade between tracks** - System smoothly transitions between different tracks

## Security

- **JWT Authentication** for secure login
- **API Gateway** for centralized authentication and authorization
- **Role-based access control** (Admin vs. regular users)
- **HTTPS/TLS** for all communications
- **Input validation** and sanitization

## Observability

### Metrics (Prometheus)
- Request rate per service
- Response latency (p50, p95, p99)
- Error rate
- Concurrent radio listeners
- Music download rate
- API call success/failure rates

### Logging (ELK Stack / Loki)
- Centralized logging from all services
- Structured logging (JSON format)
- Log aggregation and search
- Alerting based on log patterns

### Health Checks
- Kubernetes liveness probes
- Kubernetes readiness probes
- Service health endpoints (`/health`, `/ready`)

## Deployment Architecture

### Kubernetes Components
- **Deployments** - For stateless services
- **StatefulSets** - For PostgreSQL, Kafka, RabbitMQ
- **Services** - For service discovery
- **Ingress** - For external access
- **ConfigMaps** - For configuration
- **Secrets** - For sensitive data (API keys, JWT secrets)

### Helm Charts
- Separate charts for each microservice
- Environment-specific values (dev, staging, prod)
- Dependency management

### CI/CD Pipeline
- Automated testing on pull requests
- Automated builds and container image creation
- Automated deployment to Kubernetes on merge to main
- Rollback capabilities

## Project Requirements Mapping

This architecture addresses the following course requirements:

- ✅ **Microservices** (6 points) - Multiple independent services
- ✅ **Kubernetes** (6 points) - Full Kubernetes deployment
- ✅ **Event Sourcing & CQRS** (5 points) - Kafka-based event streaming
  - See [Event Sourcing & CQRS Documentation](EVENT_SOURCING_CQRS.md) for detailed implementation
- ✅ **Message Systems** (5 points) - Kafka + RabbitMQ
- ✅ **Metrics Collection** (5 points) - Prometheus
- ✅ **Centralized Logging** (5 points) - ELK Stack
- ✅ **Health Checks** (4 points) - Kubernetes health probes
- ✅ **GraphQL & gRPC** (4 points) - gRPC for inter-service communication
  - See [gRPC Implementation Documentation](GRPC_IMPLEMENTATION.md) for detailed implementation
- ✅ **Serverless Function** (5 points) - Azure Functions for audio metadata extraction
  - See [Serverless Function Documentation](SERVERLESS_FUNCTION.md) for detailed implementation
- ✅ **External API Integration** (3 points) - Facebook, YouTube, Bandcamp APIs
- ✅ **GUI** (4 points) - Svelte frontend
- ✅ **CI/CD Pipeline** (5 points) - Automated deployment
- ✅ **Helm Charts** (4 points) - Kubernetes package management
- ✅ **Cloud Deployment** (5 points) - Deployed to cloud Kubernetes

**Total: 60+ points** (exceeding the 50 point minimum)

