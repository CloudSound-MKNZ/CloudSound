"""Playback event tracking API endpoints."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from backend.shared.db.pool import get_db
from backend.analytics.src.services.playback_service import PlaybackEventService
from backend.shared.logging import get_logger
from backend.shared.metrics import playback_events_total
from ..producers.kafka_producer import publish_playback_event
import time

logger = get_logger(__name__)

router = APIRouter(prefix="/radio/playback", tags=["radio"])


class PlaybackEventRequest(BaseModel):
    """Playback event request model."""
    station_id: UUID
    track_id: UUID
    duration_seconds: Optional[int] = None


class PlaybackEventResponse(BaseModel):
    """Playback event response model."""
    id: UUID
    station_id: UUID
    track_id: UUID
    timestamp: str
    duration_seconds: Optional[int] = None


@router.post("/events", response_model=PlaybackEventResponse, status_code=status.HTTP_201_CREATED)
async def create_playback_event(
    event: PlaybackEventRequest,
    db: AsyncSession = Depends(get_db)
) -> PlaybackEventResponse:
    """Create a playback event for tracking statistics."""
    start_time = time.time()
    
    try:
        service = PlaybackEventService(db)
        playback_event = await service.create_playback_event(
            station_id=event.station_id,
            track_id=event.track_id,
            duration_seconds=event.duration_seconds
        )
        
        # Update metrics
        playback_events_total.labels(
            station_id=str(event.station_id),
            track_id=str(event.track_id)
        ).inc()
        
        # Publish to Kafka for async processing
        publish_playback_event(
            station_id=event.station_id,
            track_id=event.track_id,
            duration_seconds=event.duration_seconds
        )
        
        logger.info(
            "playback_event_created",
            event_id=str(playback_event.id),
            station_id=str(event.station_id),
            track_id=str(event.track_id),
            duration_seconds=event.duration_seconds
        )
        
        return PlaybackEventResponse(
            id=playback_event.id,
            station_id=playback_event.station_id,
            track_id=playback_event.track_id,
            timestamp=playback_event.timestamp.isoformat(),
            duration_seconds=playback_event.duration_seconds
        )
    
    except Exception as e:
        logger.error(
            "playback_event_creation_failed",
            station_id=str(event.station_id),
            track_id=str(event.track_id),
            error=str(e),
            exc_info=True
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create playback event"
        )

