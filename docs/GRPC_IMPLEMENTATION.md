# gRPC Implementation: Real-Time Playback Events

## Overview

We use **gRPC** for low-latency, high-throughput communication between the Radio Streaming Service and Analytics Service for real-time playback event tracking. gRPC provides:

- **Low latency**: Binary protocol, HTTP/2 multiplexing
- **High throughput**: Efficient serialization (Protocol Buffers)
- **Streaming**: Bidirectional streaming for real-time events
- **Type safety**: Strongly-typed contracts via `.proto` files

## Use Case

**Problem**: Radio Streaming Service needs to send playback events (track started, track completed) to Analytics Service in real-time with minimal latency.

**Current Solution**: REST API calls (HTTP/1.1, JSON) - higher latency, lower throughput

**gRPC Solution**: gRPC streaming (HTTP/2, Protocol Buffers) - lower latency, higher throughput

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│         Radio Streaming Service (gRPC Client)               │
│  • Tracks playback events                                   │
│  • Streams events to Analytics via gRPC                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ (gRPC Streaming)
                       │ HTTP/2 + Protocol Buffers
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         Analytics Service (gRPC Server)                     │
│  • Receives playback events in real-time                     │
│  • Updates statistics database                               │
│  • Publishes to Kafka for downstream processing              │
└─────────────────────────────────────────────────────────────┘
```

## Protocol Buffer Definition

**`proto/playback.proto`**:

```protobuf
syntax = "proto3";

package cloudsound.playback;

// Playback event service
service PlaybackEventService {
  // Unary RPC: Send single playback event
  rpc RecordPlaybackEvent(PlaybackEventRequest) returns (PlaybackEventResponse);
  
  // Server streaming: Get playback statistics
  rpc StreamPlaybackStatistics(StatisticsRequest) returns (stream StatisticsResponse);
  
  // Bidirectional streaming: Real-time event streaming
  rpc StreamPlaybackEvents(stream PlaybackEventRequest) returns (stream PlaybackEventResponse);
}

// Playback event request
message PlaybackEventRequest {
  string event_id = 1;
  string station_id = 2;
  string track_id = 3;
  PlaybackEventType event_type = 4;
  int64 timestamp = 5;  // Unix timestamp in milliseconds
  int32 duration_seconds = 6;  // Duration played (for completed events)
  string user_id = 7;  // Optional user ID
  map<string, string> metadata = 8;  // Additional metadata
}

// Playback event response
message PlaybackEventResponse {
  string event_id = 1;
  bool success = 2;
  string message = 3;
  int64 processed_at = 4;  // Unix timestamp in milliseconds
}

// Playback event type
enum PlaybackEventType {
  UNKNOWN = 0;
  TRACK_STARTED = 1;
  TRACK_COMPLETED = 2;
  TRACK_SKIPPED = 3;
  STATION_CHANGED = 4;
}

// Statistics request
message StatisticsRequest {
  string station_id = 1;
  int64 start_timestamp = 2;  // Unix timestamp in milliseconds
  int64 end_timestamp = 3;    // Unix timestamp in milliseconds
}

// Statistics response
message StatisticsResponse {
  string station_id = 1;
  int64 total_plays = 2;
  int64 total_duration_seconds = 3;
  map<string, int64> track_play_counts = 4;  // track_id -> play count
  int64 timestamp = 5;
}
```

## Implementation

### Generate Python Code from .proto

```bash
# Install protoc compiler
# https://grpc.io/docs/protoc-installation/

# Generate Python code
python -m grpc_tools.protoc \
  --python_out=. \
  --grpc_python_out=. \
  --proto_path=proto \
  proto/playback.proto
```

This generates:
- `proto/playback_pb2.py` - Message classes
- `proto/playback_pb2_grpc.py` - Service stubs

### gRPC Server (Analytics Service)

**`cloudsound-analytics/src/grpc/server.py`**:

```python
import grpc
from concurrent import futures
from proto import playback_pb2, playback_pb2_grpc
from cloudsound_shared.logging import get_logger
from .services.playback_service import PlaybackEventService
from cloudsound_shared.db.pool import AsyncSessionLocal

logger = get_logger(__name__)


class PlaybackEventServicer(playback_pb2_grpc.PlaybackEventServiceServicer):
    """gRPC server for playback events."""
    
    async def RecordPlaybackEvent(
        self,
        request: playback_pb2.PlaybackEventRequest,
        context: grpc.aio.ServicerContext
    ) -> playback_pb2.PlaybackEventResponse:
        """Handle unary playback event."""
        try:
            async with AsyncSessionLocal() as session:
                service = PlaybackEventService(session)
                
                await service.create_playback_event(
                    station_id=UUID(request.station_id),
                    track_id=UUID(request.track_id),
                    duration_seconds=request.duration_seconds if request.duration_seconds > 0 else None
                )
            
            logger.info(
                "grpc_playback_event_recorded",
                event_id=request.event_id,
                station_id=request.station_id,
                track_id=request.track_id
            )
            
            return playback_pb2.PlaybackEventResponse(
                event_id=request.event_id,
                success=True,
                message="Event recorded successfully",
                processed_at=int(time.time() * 1000)
            )
        
        except Exception as e:
            logger.error(
                "grpc_playback_event_failed",
                event_id=request.event_id,
                error=str(e),
                exc_info=True
            )
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return playback_pb2.PlaybackEventResponse(
                event_id=request.event_id,
                success=False,
                message=str(e),
                processed_at=int(time.time() * 1000)
            )
    
    async def StreamPlaybackEvents(
        self,
        request_iterator,
        context: grpc.aio.ServicerContext
    ) -> playback_pb2.PlaybackEventResponse:
        """Handle bidirectional streaming of playback events."""
        async for request in request_iterator:
            try:
                # Process event
                response = await self.RecordPlaybackEvent(request, context)
                
                # Send response back to client
                yield response
            
            except Exception as e:
                logger.error(
                    "grpc_stream_event_failed",
                    error=str(e),
                    exc_info=True
                )
                yield playback_pb2.PlaybackEventResponse(
                    event_id=request.event_id,
                    success=False,
                    message=str(e),
                    processed_at=int(time.time() * 1000)
                )


async def serve(port: int = 50051):
    """Start gRPC server."""
    server = grpc.aio.server(futures.ThreadPoolExecutor(max_workers=10))
    
    playback_pb2_grpc.add_PlaybackEventServiceServicer_to_server(
        PlaybackEventServicer(),
        server
    )
    
    listen_addr = f'[::]:{port}'
    server.add_insecure_port(listen_addr)
    
    logger.info(f"gRPC server starting on {listen_addr}")
    await server.start()
    await server.wait_for_termination()
```

**`cloudsound-analytics/src/main.py`** (add gRPC server):

```python
import asyncio
import threading
from .grpc.server import serve

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # ... existing code ...
    
    # Start gRPC server in background
    grpc_thread = threading.Thread(
        target=lambda: asyncio.run(serve(port=50051)),
        daemon=True
    )
    grpc_thread.start()
    logger.info("grpc_server_started", port=50051)
    
    yield
    
    # Shutdown
    logger.info("grpc_server_shutting_down")
```

### gRPC Client (Radio Streaming Service)

**`cloudsound-radio-streaming/src/grpc/client.py`**:

```python
import grpc
from proto import playback_pb2, playback_pb2_grpc
from cloudsound_shared.logging import get_logger
from cloudsound_shared.config.settings import app_settings
import time
from uuid import UUID

logger = get_logger(__name__)


class PlaybackEventClient:
    """gRPC client for sending playback events to Analytics service."""
    
    def __init__(self, analytics_service_url: str = None):
        """Initialize gRPC client.
        
        Args:
            analytics_service_url: URL of Analytics gRPC server
                Format: "host:port" (e.g., "analytics:50051")
        """
        self.url = analytics_service_url or app_settings.analytics_grpc_url
        self._channel = None
        self._stub = None
        self._stream = None
    
    def connect(self):
        """Connect to gRPC server."""
        if self._channel is None:
            self._channel = grpc.aio.insecure_channel(self.url)
            self._stub = playback_pb2_grpc.PlaybackEventServiceStub(self._channel)
            logger.info("grpc_client_connected", url=self.url)
    
    async def record_playback_event(
        self,
        station_id: UUID,
        track_id: UUID,
        event_type: str = "TRACK_STARTED",
        duration_seconds: int = None,
        user_id: str = None
    ) -> bool:
        """Send single playback event (unary RPC).
        
        Args:
            station_id: Radio station ID
            track_id: Track ID
            event_type: Event type (TRACK_STARTED, TRACK_COMPLETED, etc.)
            duration_seconds: Duration played (for completed events)
            user_id: Optional user ID
            
        Returns:
            True if successful, False otherwise
        """
        if not self._stub:
            self.connect()
        
        try:
            request = playback_pb2.PlaybackEventRequest(
                event_id=str(uuid.uuid4()),
                station_id=str(station_id),
                track_id=str(track_id),
                event_type=getattr(playback_pb2.PlaybackEventType, event_type),
                timestamp=int(time.time() * 1000),
                duration_seconds=duration_seconds or 0,
                user_id=user_id or ""
            )
            
            response = await self._stub.RecordPlaybackEvent(request)
            
            if response.success:
                logger.info(
                    "grpc_playback_event_sent",
                    event_id=response.event_id,
                    station_id=str(station_id),
                    track_id=str(track_id)
                )
                return True
            else:
                logger.warning(
                    "grpc_playback_event_failed",
                    event_id=response.event_id,
                    message=response.message
                )
                return False
        
        except Exception as e:
            logger.error(
                "grpc_playback_event_error",
                error=str(e),
                exc_info=True
            )
            return False
    
    async def start_streaming(self):
        """Start bidirectional streaming for real-time events."""
        if not self._stub:
            self.connect()
        
        self._stream = self._stub.StreamPlaybackEvents()
        logger.info("grpc_streaming_started")
    
    async def send_stream_event(
        self,
        station_id: UUID,
        track_id: UUID,
        event_type: str = "TRACK_STARTED",
        duration_seconds: int = None
    ):
        """Send event through streaming connection."""
        if not self._stream:
            await self.start_streaming()
        
        request = playback_pb2.PlaybackEventRequest(
            event_id=str(uuid.uuid4()),
            station_id=str(station_id),
            track_id=str(track_id),
            event_type=getattr(playback_pb2.PlaybackEventType, event_type),
            timestamp=int(time.time() * 1000),
            duration_seconds=duration_seconds or 0
        )
        
        await self._stream.write(request)
        
        # Read response
        response = await self._stream.read()
        return response.success
    
    async def close(self):
        """Close gRPC connection."""
        if self._stream:
            await self._stream.done_writing()
            await self._stream
        if self._channel:
            await self._channel.close()
        logger.info("grpc_client_closed")


# Global client instance
_client: PlaybackEventClient = None


def get_grpc_client() -> PlaybackEventClient:
    """Get or create gRPC client instance."""
    global _client
    if _client is None:
        _client = PlaybackEventClient()
        _client.connect()
    return _client
```

**Usage in Radio Streaming Service**:

```python
# In playback.py
from .grpc.client import get_grpc_client

async def create_playback_event(event: PlaybackEventRequest):
    """Create playback event via gRPC."""
    client = get_grpc_client()
    
    success = await client.record_playback_event(
        station_id=event.station_id,
        track_id=event.track_id,
        event_type="TRACK_STARTED",
        duration_seconds=event.duration_seconds
    )
    
    if success:
        return PlaybackEventResponse(
            event_id=event.event_id,
            success=True
        )
    else:
        raise HTTPException(status_code=500, detail="Failed to record event")
```

## Deployment

### Kubernetes Service

**`infrastructure/kubernetes/analytics/grpc-service.yaml`**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: analytics-grpc
  namespace: cloudsound
spec:
  type: ClusterIP
  ports:
    - port: 50051
      targetPort: 50051
      protocol: TCP
      name: grpc
  selector:
    app: analytics
```

### Docker Configuration

**`cloudsound-analytics/Dockerfile`** (add gRPC port):

```dockerfile
EXPOSE 8007 50051
```

## Performance Comparison

| Metric | REST API | gRPC |
|--------|----------|------|
| **Latency** | ~50-100ms | ~5-10ms |
| **Throughput** | ~1000 req/s | ~10,000 req/s |
| **Payload Size** | ~500 bytes (JSON) | ~200 bytes (Protobuf) |
| **Connection** | HTTP/1.1 (new per request) | HTTP/2 (persistent) |
| **Serialization** | JSON (text) | Protobuf (binary) |

## Monitoring

### gRPC Metrics

- **Request rate**: Requests per second
- **Latency**: P50, P95, P99 latencies
- **Error rate**: Percentage of failed requests
- **Stream duration**: Average stream connection duration
- **Message size**: Average request/response size

### Health Checks

gRPC health checking protocol:

```python
from grpc_health.v1 import health_pb2, health_pb2_grpc

class HealthServicer(health_pb2_grpc.HealthServicer):
    def Check(self, request, context):
        return health_pb2.HealthCheckResponse(
            status=health_pb2.HealthCheckResponse.SERVING
        )
```

## Benefits

1. **Low Latency**: Binary protocol, HTTP/2 multiplexing
2. **High Throughput**: Efficient serialization, persistent connections
3. **Type Safety**: Strongly-typed contracts via Protocol Buffers
4. **Streaming**: Bidirectional streaming for real-time communication
5. **Language Agnostic**: Works across Python, Go, Java, etc.

## When to Use gRPC vs REST

**Use gRPC for**:
- Inter-service communication (microservices)
- Real-time streaming
- High-throughput scenarios
- Low-latency requirements

**Use REST for**:
- External APIs (browser, mobile apps)
- Public APIs
- Simple request/response patterns
- When JSON is preferred

## References

- **Protocol Buffers**: https://protobuf.dev/
- **gRPC Python**: https://grpc.io/docs/languages/python/
- **gRPC Best Practices**: https://grpc.io/docs/guides/best-practices/

