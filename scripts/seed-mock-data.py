#!/usr/bin/env python3
"""Seed database with mock data for development and testing.
    
This script should ONLY be run in development or test environments.
It will refuse to run in production for safety.
"""
import asyncio
import sys
import os

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.shared.config.settings import app_settings

from sqlalchemy.ext.asyncio import AsyncSession
from backend.shared.db.pool import AsyncSessionLocal, engine, Base
from backend.shared.models.base import Base, UUIDMixin, TimestampMixin
from sqlalchemy import Column, String, Boolean, ForeignKey, Text, DateTime, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime, timedelta
import uuid

# Mock data models (simplified versions for seeding)
class AdminUser(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "admin_users"
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    name = Column(String(255))
    role = Column(String(50), default="admin")
    tenant_id = Column(UUID(as_uuid=True), nullable=True)
    is_active = Column(Boolean, default=True)

class Artist(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "artists"
    name = Column(String(255), nullable=False)
    genre = Column(String(100))
    bio = Column(Text)
    image_url = Column(String(500))

class Track(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "tracks"
    title = Column(String(255), nullable=False)
    artist_id = Column(UUID(as_uuid=True), ForeignKey("artists.id"), nullable=False)
    duration_seconds = Column(Integer)
    file_path = Column(String(500))  # Path in MinIO/S3
    source_url = Column(String(500))  # Original YouTube/Bandcamp URL
    source_type = Column(String(50))  # "youtube" or "bandcamp"
    artist = relationship("Artist", backref="tracks")

class RadioStation(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "radio_stations"
    name = Column(String(255), nullable=False)
    description = Column(Text)
    station_type = Column(String(50))  # "upcoming", "genre", "past_performers"
    genre = Column(String(100), nullable=True)  # For genre stations

class StationTrack(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "station_tracks"
    station_id = Column(UUID(as_uuid=True), ForeignKey("radio_stations.id"), nullable=False)
    track_id = Column(UUID(as_uuid=True), ForeignKey("tracks.id"), nullable=False)
    play_order = Column(Integer, default=0)
    station = relationship("RadioStation", backref="station_tracks")
    track = relationship("Track", backref="station_tracks")

class Concert(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "concerts"
    title = Column(String(255), nullable=False)
    date = Column(DateTime, nullable=False)
    location = Column(String(255))
    description = Column(Text)
    facebook_event_id = Column(String(100))
    status = Column(String(50), default="scheduled")  # scheduled, completed, cancelled

class ConcertArtist(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "concert_artists"
    concert_id = Column(UUID(as_uuid=True), ForeignKey("concerts.id"), nullable=False)
    artist_id = Column(UUID(as_uuid=True), ForeignKey("artists.id"), nullable=False)
    concert = relationship("Concert", backref="concert_artists")
    artist = relationship("Artist", backref="concert_artists")

# Mock data
MOCK_ARTISTS = [
    {"name": "The Local Band", "genre": "Rock", "bio": "A local rock band known for energetic live performances."},
    {"name": "Jazz Collective", "genre": "Jazz", "bio": "Smooth jazz ensemble with a modern twist."},
    {"name": "Electronic Dreams", "genre": "Electronic", "bio": "Electronic music producer and DJ."},
    {"name": "Acoustic Sessions", "genre": "Folk", "bio": "Intimate acoustic performances."},
    {"name": "Metal Mayhem", "genre": "Metal", "bio": "Heavy metal band with powerful riffs."},
    {"name": "Indie Vibes", "genre": "Indie", "bio": "Indie rock with catchy melodies."},
    {"name": "Blues Brothers", "genre": "Blues", "bio": "Classic blues with soul."},
    {"name": "Pop Sensation", "genre": "Pop", "bio": "Catchy pop tunes for everyone."},
]

MOCK_TRACKS = [
    {"title": "Rock Anthem", "genre": "Rock", "duration": 240},
    {"title": "Jazz Night", "genre": "Jazz", "duration": 320},
    {"title": "Electronic Pulse", "genre": "Electronic", "duration": 180},
    {"title": "Acoustic Ballad", "genre": "Folk", "duration": 280},
    {"title": "Metal Thunder", "genre": "Metal", "duration": 300},
    {"title": "Indie Dream", "genre": "Indie", "duration": 220},
    {"title": "Blues Journey", "genre": "Blues", "duration": 350},
    {"title": "Pop Hit", "genre": "Pop", "duration": 200},
    {"title": "Rock Out", "genre": "Rock", "duration": 260},
    {"title": "Jazz Improv", "genre": "Jazz", "duration": 400},
]

MOCK_STATIONS = [
    {"name": "Upcoming Bands", "type": "upcoming", "description": "Music from artists with upcoming concerts"},
    {"name": "Rock Radio", "type": "genre", "genre": "Rock", "description": "All rock, all the time"},
    {"name": "Jazz Lounge", "type": "genre", "genre": "Jazz", "description": "Smooth jazz for your evening"},
    {"name": "Electronic Beats", "type": "genre", "genre": "Electronic", "description": "Electronic music selection"},
    {"name": "Past Performers", "type": "past_performers", "description": "Music from past concert performers"},
]

async def seed_data():
    """Seed database with mock data."""
    async with AsyncSessionLocal() as session:
        try:
            # Create admin user
            admin = AdminUser(
                id=uuid.uuid4(),
                email="admin@cloudsound.local",
                password_hash="$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyY5Y5Y5Y5Y5",  # password: admin123
                name="Admin User",
                role="admin",
                is_active=True,
            )
            session.add(admin)
            await session.flush()
            
            # Create artists
            artists = {}
            for artist_data in MOCK_ARTISTS:
                artist = Artist(
                    id=uuid.uuid4(),
                    name=artist_data["name"],
                    genre=artist_data["genre"],
                    bio=artist_data["bio"],
                )
                session.add(artist)
                await session.flush()
                artists[artist_data["genre"]] = artist
            
            # Create tracks (assign to artists by genre)
            tracks = []
            for i, track_data in enumerate(MOCK_TRACKS):
                artist = artists.get(track_data["genre"], list(artists.values())[0])
                track = Track(
                    id=uuid.uuid4(),
                    title=track_data["title"],
                    artist_id=artist.id,
                    duration_seconds=track_data["duration"],
                    file_path=f"tracks/{track_data['title'].lower().replace(' ', '_')}.mp3",
                    source_url=f"https://youtube.com/watch?v=mock{i}",
                    source_type="youtube",
                )
                session.add(track)
                await session.flush()
                tracks.append(track)
            
            # Create radio stations
            stations = {}
            for station_data in MOCK_STATIONS:
                station = RadioStation(
                    id=uuid.uuid4(),
                    name=station_data["name"],
                    description=station_data["description"],
                    station_type=station_data["type"],
                    genre=station_data.get("genre"),
                )
                session.add(station)
                await session.flush()
                stations[station_data["name"]] = station
            
            # Assign tracks to stations
            for station_name, station in stations.items():
                if station.station_type == "genre":
                    # Assign tracks matching the genre
                    genre_tracks = [t for t in tracks if any(a.genre == station.genre for a in [artists.get(station.genre)])]
                    if not genre_tracks:
                        genre_tracks = tracks[:3]  # Fallback
                elif station.station_type == "upcoming":
                    # Assign first 5 tracks
                    genre_tracks = tracks[:5]
                else:
                    # Past performers - random selection
                    genre_tracks = tracks[3:8]
                
                for order, track in enumerate(genre_tracks):
                    station_track = StationTrack(
                        id=uuid.uuid4(),
                        station_id=station.id,
                        track_id=track.id,
                        play_order=order,
                    )
                    session.add(station_track)
            
            # Create upcoming concerts
            upcoming_date = datetime.utcnow() + timedelta(days=7)
            concert = Concert(
                id=uuid.uuid4(),
                title="Summer Music Festival",
                date=upcoming_date,
                location="Main Stage",
                description="A great summer music festival featuring local artists.",
                status="scheduled",
            )
            session.add(concert)
            await session.flush()
            
            # Link artists to concert
            for artist in list(artists.values())[:3]:
                concert_artist = ConcertArtist(
                    id=uuid.uuid4(),
                    concert_id=concert.id,
                    artist_id=artist.id,
                )
                session.add(concert_artist)
            
            await session.commit()
            print("✅ Mock data seeded successfully!")
            print(f"   - {len(artists)} artists")
            print(f"   - {len(tracks)} tracks")
            print(f"   - {len(stations)} radio stations")
            print(f"   - 1 concert")
            print(f"   - Admin user: admin@cloudsound.local / admin123")
            
        except Exception as e:
            await session.rollback()
            print(f"❌ Error seeding data: {e}")
            raise

async def main():
    """Main entry point."""
    # Safety check: refuse to seed in production
    if app_settings.environment == "production":
        print("❌ ERROR: Cannot seed mock data in production environment!")
        print(f"   Current environment: {app_settings.environment}")
        print("   This script is only for development and test environments.")
        sys.exit(1)
    
    if not app_settings.seed_mock_data:
        print("⚠️  WARNING: SEED_MOCK_DATA is disabled in configuration.")
        print(f"   Current environment: {app_settings.environment}")
        response = input("   Continue anyway? (yes/no): ")
        if response.lower() != "yes":
            print("   Aborted.")
            sys.exit(0)
    
    print(f"🌱 Seeding mock data for environment: {app_settings.environment}")
    
    # Create tables if they don't exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    await seed_data()

if __name__ == "__main__":
    asyncio.run(main())

