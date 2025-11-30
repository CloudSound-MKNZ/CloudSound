# Phase 3 Testing Guide - User Story 1: Radio Streaming

This guide helps you test Phase 3 functionality to ensure everything works correctly before proceeding to Phase 4.

## Quick Test Script

Run the automated test script:

```bash
./scripts/test-phase3.sh
```

This script will:
- ✅ Check if infrastructure services are running
- ✅ Verify backend services are accessible
- ✅ Test API endpoints
- ✅ Check database connectivity and data
- ✅ Verify metrics endpoints

## Manual Testing Steps

### Prerequisites

1. **Start Infrastructure**:
   ```bash
   docker compose -f infrastructure/docker/docker-compose.dev.yml up -d
   ```

2. **Run Database Migrations**:
   ```bash
   cd backend/shared/db
   alembic upgrade head
   cd ../../..
   ```

3. **Seed Mock Data**:
   ```bash
   python scripts/seed-mock-data.py
   ```

4. **Start Backend Services**:

   **Terminal 1 - Radio Streaming Service**:
   ```bash
   cd backend/radio-streaming
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   uvicorn src.main:app --reload --port 8004
   ```

   **Terminal 2 - Analytics Service**:
   ```bash
   cd backend/analytics
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   uvicorn src.main:app --reload --port 8007
   ```

5. **Start Frontend**:
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

### Test Checklist

#### ✅ API Endpoints

1. **Health Check**
   ```bash
   curl http://localhost:8004/health
   ```
   Expected: `{"status": "healthy"}`

2. **List Radio Stations**
   ```bash
   curl http://localhost:8004/api/v1/radio/stations
   ```
   Expected: JSON array of radio stations

3. **Get Station Details**
   ```bash
   # Get a station ID from the list above, then:
   curl http://localhost:8004/api/v1/radio/stations/{STATION_ID}
   ```
   Expected: Station details with tracks

4. **Stream Endpoint** (for a specific track)
   ```bash
   curl -I http://localhost:8004/api/v1/radio/stream/{TRACK_ID}
   ```
   Expected: HTTP 200 or 206 (range request support)

5. **Metrics**
   ```bash
   curl http://localhost:8004/metrics
   ```
   Expected: Prometheus metrics in text format

6. **API Documentation**
   - Open: http://localhost:8004/docs
   - Verify all endpoints are documented
   - Try the "Try it out" feature

#### ✅ Frontend Testing

1. **Open Frontend**
   - Navigate to: http://localhost:5173
   - Should see the CloudSound homepage

2. **Radio Stations Page**
   - Navigate to: http://localhost:5173/radio
   - Should see list of radio stations
   - Stations should be organized by type (upcoming, past, genre)

3. **Station Selection**
   - Click on a radio station
   - Should navigate to station detail page
   - Should see station information and track list

4. **Audio Player**
   - Click "Play" button
   - Audio player should appear
   - Player should show current track information
   - Controls should be visible (play/pause, next, previous)

5. **Crossfade Testing** (if audio files are available)
   - Let a track play to completion
   - Next track should start with smooth crossfade
   - No gaps or abrupt transitions
   - Crossfade duration should be ~3 seconds

6. **Manual Track Navigation**
   - Click "Next" button
   - Track should change with crossfade
   - Click "Previous" button
   - Should go back to previous track

#### ✅ Database Verification

1. **Check Tables Exist**:
   ```bash
   PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "\dt"
   ```
   Should see: `artists`, `tracks`, `radio_stations`, `station_tracks`, `playback_events`

2. **Check Data**:
   ```bash
   PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "SELECT COUNT(*) FROM artists;"
   PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "SELECT COUNT(*) FROM tracks;"
   PGPASSWORD=cloudsound_dev psql -h localhost -U cloudsound -d cloudsound -c "SELECT COUNT(*) FROM radio_stations;"
   ```

#### ✅ Kafka Integration

1. **Check Kafka is Running**:
   ```bash
   docker compose -f infrastructure/docker/docker-compose.dev.yml ps kafka
   ```

2. **Verify Playback Events**:
   - Play a track in the frontend
   - Check analytics service logs for consumed events
   - Or check Kafka topics (requires Kafka tools):
     ```bash
     # If you have kafka-console-consumer available
     docker exec -it $(docker ps -q -f name=kafka) kafka-console-consumer \
       --bootstrap-server localhost:9092 \
       --topic radio.playback.events \
       --from-beginning
     ```

#### ✅ Observability

1. **Prometheus Metrics**:
   - Open: http://localhost:8004/metrics
   - Look for metrics like:
     - `http_requests_total`
     - `radio_streaming_*`
     - `kafka_producer_*`

2. **Structured Logging**:
   - Check service logs for JSON-formatted log entries
   - Look for correlation IDs in logs
   - Verify log levels (INFO, ERROR, etc.)

3. **Health Checks**:
   - `/health` - Basic health check
   - `/ready` - Readiness probe (if implemented)

## Common Issues & Solutions

### Issue: "No stations found"
**Solution**: Run the seed script:
```bash
python scripts/seed-mock-data.py
```

### Issue: "Cannot connect to database"
**Solution**: 
1. Check PostgreSQL is running: `docker compose -f infrastructure/docker/docker-compose.dev.yml ps postgres`
2. Wait a few seconds for PostgreSQL to initialize
3. Verify connection string in environment variables

### Issue: "Audio doesn't play"
**Solution**:
- Audio files need to be uploaded to MinIO
- Tracks in database need valid `file_path` pointing to MinIO objects
- For testing, you can use mock audio files or test with HTTP range requests

### Issue: "Frontend can't connect to backend"
**Solution**:
1. Check backend is running on port 8004
2. Check CORS settings in `backend/radio-streaming/src/main.py`
3. Verify API URL in `frontend/src/lib/api/client.ts`

### Issue: "Kafka connection errors"
**Solution**:
1. Check Kafka is running: `docker compose -f infrastructure/docker/docker-compose.dev.yml ps kafka`
2. Wait for Kafka to fully start (can take 30+ seconds)
3. Check Kafka logs: `docker compose -f infrastructure/docker/docker-compose.dev.yml logs kafka`

## Success Criteria

Phase 3 is working correctly if:

- ✅ All API endpoints return expected responses
- ✅ Frontend displays radio stations
- ✅ Audio player appears and functions
- ✅ Crossfade transitions work smoothly
- ✅ Playback events are tracked (Kafka/analytics)
- ✅ Metrics are exposed and accessible
- ✅ Logging is structured and includes correlation IDs
- ✅ Database contains test data
- ✅ All services start without errors

## Next Steps

Once Phase 3 testing passes:

1. ✅ Mark Phase 3 as tested in your notes
2. 📝 Document any issues found
3. 🚀 Proceed to **Phase 4: User Story 2 - Browse Concert Schedule**

## Notes

- For audio playback to work, you need actual MP3 files in MinIO
- The seed script creates database records but doesn't upload audio files
- Crossfade testing requires multiple tracks to be available
- Kafka integration can be verified through analytics service logs

