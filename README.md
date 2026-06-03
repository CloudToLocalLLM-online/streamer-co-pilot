# Streamer Co-Pilot 🎮

A Flutter desktop app for streamers — real-time chat dashboard, stream status overlay, and bot controls.

Connects to the **streamer-co-pilot-service** (Python/FastAPI bot backend).

## Features

- **Dashboard** — stream status (live/offline), viewer count, game, title, recent chat messages
- **Chat tab** — scrollable chat viewer with message send
- **Settings** — configure bot API URL, connection management

## Quick Start

```bash
# Clone
git clone https://github.com/imrightguy/streamer-co-pilot.git
cd streamer-co-pilot

# Build & run
flutter pub get
flutter run -d linux
```

Requires the bot backend: [streamer-co-pilot-service](https://github.com/imrightguy/streamer-co-pilot-service)

```bash
TWITCH_CLIENT_ID=xxx \
TWITCH_CLIENT_SECRET=*** \
BOT_ID=123456 \
CHANNEL_NAME=your_channel \
python3 api.py
```

Then point the app to `http://localhost:8510` and connect.
