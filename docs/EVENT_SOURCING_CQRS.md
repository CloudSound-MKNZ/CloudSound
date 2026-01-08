# Event Sourcing & CQRS Implementation

## Overview

CloudSound implements **Event Sourcing** and **CQRS (Command Query Responsibility Segregation)** patterns using Apache Kafka as the event store. This architecture provides:

- **Event Sourcing**: All state changes are stored as immutable events in Kafka topics
- **CQRS**: Commands (writes) and Queries (reads) are separated into different models and data stores
- **Event Replay**: Ability to reconstruct state by replaying events from the beginning
- **Decoupled Services**: Services communicate asynchronously through events

## Architecture

### Event Store: Apache Kafka

Kafka serves as the **immutable event log** where all domain events are stored:

```
┌─────────────────────────────────────────────────────────────┐
│                    Event Store (Kafka)                      │
├─────────────────────────────────────────────────────────────┤
│ Topic: radio.playback.events                                │
│ Topic: concerts.created                                     │
│ Topic: concerts.updated                                     │
│ Topic: facebook.events.raw                                 │
│ Topic: facebook.events.parsed                               │
│ Topic: facebook.events.enriched                             │
│ Topic: music.discovery.requests                             │
│ Topic: music.downloaded                                     │
└─────────────────────────────────────────────────────────────┘
```

### Command Side (Write Model)

**Commands** represent user intentions to change state. They:
- Validate business rules
- Generate domain events
- Publish events to Kafka
- Update write database (if needed for immediate consistency)

**Example: Concert Creation Command**

```python
# Command Handler (Concert Management Service)
async def create_concert(command: CreateConcertCommand):
    # 1. Validate business rules
    validate_concert_date(command.date)
    
    # 2. Create aggregate in write database
    concert = Concert(...)
    db.add(concert)
    await db.commit()
    
    # 3. Publish event to Kafka (Event Store)
    event = {
        "event_type": "concert.created",
        "concert_id": str(concert.id),
        "location": command.location,
        "date": command.date.isoformat(),
        "artists": command.artists,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    kafka_producer.send(
        topic="concerts.created",
        value=event,
        key=str(concert.id)  # Partition by concert_id for ordering
    )
```

**Location**: `cloudsound-concert-management/src/producers/kafka_producer.py`

### Query Side (Read Model)

**Queries** read from optimized read models (PostgreSQL) that are:
- Denormalized for fast reads
- Updated asynchronously by event consumers
- Separate from write models

**Example: Playback Events Query**

```python
# Query Handler (Analytics Service)
async def get_playback_statistics(station_id: UUID, start_date: datetime):
    # Read from optimized read model (PostgreSQL)
    query = select(PlaybackEvent).where(
        PlaybackEvent.station_id == station_id,
        PlaybackEvent.timestamp >= start_date
    )
    result = await db.execute(query)
    return result.scalars().all()
```

**Location**: `cloudsound-analytics/src/services/playback_service.py`

### Event Consumers (Projection Builders)

Event consumers read from Kafka and update read models:

```python
# Event Consumer (Analytics Service)
class PlaybackEventConsumer:
    async def process_message(self, event: Dict):
        # 1. Read event from Kafka (Event Store)
        station_id = UUID(event["station_id"])
        track_id = UUID(event["track_id"])
        
        # 2. Update read model (PostgreSQL)
        playback_event = PlaybackEvent(
            station_id=station_id,
            track_id=track_id,
            timestamp=event["timestamp"]
        )
        db.add(playback_event)
        await db.commit()
```

**Location**: `cloudsound-analytics/src/consumers/playback_consumer.py`

## Event Sourcing Pattern

### Event Store Structure

Each event in Kafka contains:

```json
{
  "event_type": "concert.created",
  "event_id": "uuid",
  "aggregate_id": "concert-uuid",
  "timestamp": "2025-01-15T10:30:00Z",
  "data": {
    "location": "Venue Name",
    "date": "2025-02-20",
    "artists": ["Artist 1", "Artist 2"]
  },
  "metadata": {
    "user_id": "admin-uuid",
    "correlation_id": "request-uuid"
  }
}
```

### Event Types

| Event Type | Topic | Producer | Consumer | Purpose |
|------------|-------|----------|----------|---------|
| `concert.created` | `concerts.created` | Concert Management | Music Discovery | Trigger music discovery |
| `concert.updated` | `concerts.updated` | Concert Management | Music Discovery | Update music links |
| `playback.started` | `radio.playback.events` | Radio Streaming | Analytics | Track playback |
| `playback.completed` | `radio.playback.events` | Radio Streaming | Analytics | Complete playback stats |
| `facebook.event.raw` | `facebook.events.raw` | Event Manager | Event Manager | Raw Facebook events |
| `facebook.event.parsed` | `facebook.events.parsed` | Event Manager | Concert Management | Parsed event data |
| `music.downloaded` | `music.downloaded` | Music Discovery | Radio Streaming | New track available |

## CQRS Pattern

### Command/Query Separation

**Commands (Write Operations)**:
- `CreateConcertCommand` → Publishes `concert.created` event
- `UpdateConcertCommand` → Publishes `concert.updated` event
- `StartPlaybackCommand` → Publishes `playback.started` event

**Queries (Read Operations)**:
- `GetConcertQuery` → Reads from PostgreSQL
- `GetPlaybackStatisticsQuery` → Reads from PostgreSQL
- `GetUpcomingConcertsQuery` → Reads from PostgreSQL

### Write Model (Command Side)

**Location**: Service-specific databases (PostgreSQL)

- Stores current state for validation
- Optimized for writes
- May be normalized

**Example**: `cloudsound-concert-management` database stores concerts for validation before publishing events.

### Read Model (Query Side)

**Location**: Service-specific read databases (PostgreSQL)

- Denormalized for fast reads
- Updated asynchronously via event consumers
- Optimized for specific query patterns

**Example**: `cloudsound-analytics` database stores aggregated playback statistics.

## Event Replay

### Reconstructing State

Events can be replayed from Kafka to reconstruct state:

```python
# Event Replay Service
class EventReplayService:
    async def replay_events(
        self,
        topic: str,
        from_offset: int = 0,
        to_offset: Optional[int] = None
    ):
        """Replay events from Kafka to reconstruct state."""
        consumer = KafkaConsumerClient(
            topics=[topic],
            group_id=f"replay-{uuid.uuid4()}",  # Unique group for replay
            auto_offset_reset="earliest"  # Start from beginning
        )
        
        state = {}
        
        for message in consumer.consume():
            event = message.value
            # Apply event to state
            state = self.apply_event(state, event)
            
            if to_offset and message.offset >= to_offset:
                break
        
        return state
    
    def apply_event(self, state: Dict, event: Dict) -> Dict:
        """Apply event to current state."""
        event_type = event["event_type"]
        
        if event_type == "concert.created":
            state["concerts"][event["concert_id"]] = {
                "location": event["location"],
                "date": event["date"],
                "artists": event["artists"]
            }
        elif event_type == "concert.updated":
            if event["concert_id"] in state["concerts"]:
                state["concerts"][event["concert_id"]].update({
                    "location": event.get("location"),
                    "artists": event.get("artists")
                })
        
        return state
```

### Use Cases for Event Replay

1. **Recovery**: Rebuild read models after data loss
2. **Debugging**: Replay events to understand state changes
3. **Testing**: Replay events in test environments
4. **Migration**: Rebuild read models with new structure
5. **Analytics**: Replay events for historical analysis

## Implementation Examples

### Example 1: Concert Creation (Event Sourcing)

**Command Side** (`cloudsound-concert-management`):

```python
# 1. Command received
@router.post("/concerts")
async def create_concert(command: CreateConcertCommand):
    # 2. Create aggregate
    concert = Concert(
        location=command.location,
        date=command.date,
        artists=command.artists
    )
    db.add(concert)
    await db.commit()
    
    # 3. Publish event to event store (Kafka)
    producer.publish_concert_created(
        concert_id=concert.id,
        location=concert.location,
        date=concert.date,
        artists=[a.name for a in concert.artists]
    )
    
    return concert
```

**Event Consumer** (`cloudsound-music-discovery`):

```python
# 4. Event consumed from Kafka
async def process_concert_created(event: Dict):
    # 5. Update read model (trigger music discovery)
    links = extract_links(event["description"])
    for link in links:
        queue_download(link)
```

### Example 2: Playback Tracking (CQRS)

**Command Side** (`cloudsound-radio-streaming`):

```python
# Write: Publish event
def publish_playback_event(station_id, track_id):
    event = {
        "station_id": str(station_id),
        "track_id": str(track_id),
        "timestamp": datetime.utcnow().isoformat()
    }
    kafka_producer.send("radio.playback.events", value=event)
```

**Query Side** (`cloudsound-analytics`):

```python
# Read: Query optimized read model
async def get_playback_statistics(station_id: UUID):
    return await db.execute(
        select(PlaybackEvent)
        .where(PlaybackEvent.station_id == station_id)
        .order_by(PlaybackEvent.timestamp.desc())
    )
```

## Benefits

1. **Scalability**: Read and write models can scale independently
2. **Performance**: Read models optimized for specific queries
3. **Audit Trail**: Complete history of all state changes
4. **Flexibility**: Easy to add new read models without changing write model
5. **Resilience**: Can replay events to recover from failures
6. **Decoupling**: Services communicate through events, not direct calls

## Event Store Retention

Kafka topics are configured with retention policies:

- **Short-term events** (playback events): 7 days retention
- **Medium-term events** (concerts, music): 30 days retention
- **Long-term events** (audit logs): 90 days retention

For permanent event storage, events can be archived to:
- Azure Blob Storage
- PostgreSQL (event log table)
- Data warehouse for analytics

## Monitoring

### Event Store Metrics

- **Event production rate**: Events/second per topic
- **Consumer lag**: How far behind consumers are
- **Event size**: Average event size in bytes
- **Replay time**: Time to replay events for state reconstruction

### Health Checks

- Kafka connectivity
- Consumer group health
- Event processing latency
- Read model synchronization status

## References

- **Kafka Producer**: `cloudsound-concert-management/src/producers/kafka_producer.py`
- **Kafka Consumer**: `cloudsound-analytics/src/consumers/playback_consumer.py`
- **Event Types**: See `docs/PROJECT_DESIGN.md` for complete event catalog
- **Constitution**: `memory/constitution.md` - Event-driven communication requirements

