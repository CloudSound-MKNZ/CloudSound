# Radio Streaming Service

Handles audio streaming, radio station management, and playback event tracking.

## Features

- Radio station management
- Audio streaming with HTTP range requests
- Crossfade support (client-side)
- Kafka consumer for music updates
- Playback event tracking
- gRPC client for music metadata

## Development

```bash
cd backend/radio-streaming
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8004
```

