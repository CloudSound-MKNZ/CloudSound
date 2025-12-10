#!/usr/bin/env python3
"""Seed concerts data directly into the database."""
import asyncio
import sys
import os
from datetime import datetime, timedelta, timezone
import uuid

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.ext.asyncio import AsyncSession
from backend.shared.db.pool import AsyncSessionLocal
from backend.shared.config.settings import app_settings

# Import models using full paths (PYTHONPATH is /app)
from backend.concert_management.src.models.concert import Concert
from backend.concert_management.src.models.concert_artist import ConcertArtist

async def seed_concerts():
    """Seed concerts into the database."""
    async with AsyncSessionLocal() as session:
        try:
            # Get some artists (we'll use their IDs)
            from sqlalchemy import select
            from backend.radio_streaming.src.models.artist import Artist
            
            result = await session.execute(select(Artist).limit(10))
            artists = result.scalars().all()
            
            if not artists:
                print("❌ No artists found. Please seed artists first.")
                return
            
            print(f"✅ Found {len(artists)} artists")
            
            # Create upcoming concerts
            concerts_data = [
                {
                    "date": datetime.now(timezone.utc) + timedelta(days=7),
                    "location": "Main Stage, City Center",
                    "description": "Summer Music Festival featuring top local artists",
                    "artists": artists[:3] if len(artists) >= 3 else artists
                },
                {
                    "date": datetime.now(timezone.utc) + timedelta(days=14),
                    "location": "Riverside Park",
                    "description": "Outdoor concert series - bring your blankets!",
                    "artists": artists[2:5] if len(artists) >= 5 else artists
                },
                {
                    "date": datetime.now(timezone.utc) + timedelta(days=21),
                    "location": "Grand Theater",
                    "description": "Intimate acoustic performance",
                    "artists": artists[1:3] if len(artists) >= 3 else artists[:1]
                },
                {
                    "date": datetime.now(timezone.utc) + timedelta(days=30),
                    "location": "Stadium Arena",
                    "description": "Major concert event - tickets selling fast!",
                    "artists": artists[:4] if len(artists) >= 4 else artists
                },
                {
                    "date": datetime.now(timezone.utc) + timedelta(days=45),
                    "location": "Jazz Club Downtown",
                    "description": "Jazz night with special guests",
                    "artists": artists[3:6] if len(artists) >= 6 else artists
                }
            ]
            
            created_count = 0
            for concert_data in concerts_data:
                concert = Concert(
                    id=uuid.uuid4(),
                    date=concert_data["date"],
                    location=concert_data["location"],
                    description=concert_data["description"],
                    version=1
                )
                session.add(concert)
                await session.flush()
                
                # Link artists to concert
                for artist in concert_data["artists"]:
                    concert_artist = ConcertArtist(
                        id=uuid.uuid4(),
                        concert_id=concert.id,
                        artist_id=artist.id
                    )
                    session.add(concert_artist)
                
                created_count += 1
                print(f"  Created concert: {concert.location} on {concert.date.strftime('%Y-%m-%d')}")
            
            await session.commit()
            print(f"\n✅ Successfully created {created_count} concerts!")
            
        except Exception as e:
            await session.rollback()
            print(f"❌ Error seeding concerts: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == "__main__":
    print("🌱 Seeding concerts...")
    asyncio.run(seed_concerts())

