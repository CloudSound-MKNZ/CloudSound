# Development Scripts

## Mock Data and Testing

### Seed Mock Data

Seed the database with mock data for development and testing:

```bash
# Make sure PostgreSQL is running (via docker-compose)
cd /home/tef/Gits/CloudSound
python scripts/seed-mock-data.py
```

This will create:
- 1 admin user (admin@cloudsound.local / admin123)
- 8 artists across different genres
- 10 tracks
- 5 radio stations
- 1 upcoming concert

### Mock API Clients

The system uses mock implementations of external APIs by default for development. These are located in `backend/shared/clients/mock_apis.py`:

- **MockYouTubeClient**: Returns mock YouTube video data
- **MockBandcampClient**: Returns mock Bandcamp album/track data
- **MockFacebookEventsClient**: Returns mock Facebook event data

To use real APIs, set `USE_MOCK_APIS = False` in `backend/shared/clients/mock_apis.py` and configure API keys in environment variables.

### Sample Music Files

For testing audio streaming, you'll need sample MP3 files. Options:

1. **Use royalty-free music**: Download from sources like:
   - [Free Music Archive](https://freemusicarchive.org/)
   - [Incompetech](https://incompetech.com/music/royalty-free/)
   - [Bensound](https://www.bensound.com/)

2. **Generate test audio**: Use tools like `ffmpeg` to generate test tones:
   ```bash
   # Generate 30-second test tone
   ffmpeg -f lavfi -i "sine=frequency=440:duration=30" -c:a libmp3lame test_tone.mp3
   ```

3. **Place files in MinIO**: Upload sample files to MinIO bucket:
   ```bash
   # Using MinIO client
   mc cp test_tone.mp3 cloudsound-music/tracks/
   ```

### Development Workflow

1. **Start infrastructure**:
   ```bash
   docker-compose -f infrastructure/docker/docker-compose.yml up -d
   ```

2. **Run migrations**:
   ```bash
   cd backend/shared/db
   alembic upgrade head
   ```

3. **Seed mock data**:
   ```bash
   python scripts/seed-mock-data.py
   ```

4. **Start services**:
   ```bash
   # In separate terminals
   cd backend/authentication && uvicorn src.main:app --reload --port 8006
   cd backend/radio-streaming && uvicorn src.main:app --reload --port 8004
   # ... etc
   ```

5. **Start frontend**:
   ```bash
   cd frontend
   npm install  # May need Node.js 20+ for SvelteKit
   npm run dev
   ```

