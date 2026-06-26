# Streamer Co-Pilot 🎮

A Flutter desktop app for streamers — real-time chat dashboard, stream status overlay, and bot controls.

The Python/FastAPI bot service lives in `service/` — same repo, no separate repository needed.

## Features

- **Dashboard** — stream status (live/offline), viewer count, game, title, recent chat messages
- **Chat tab** — scrollable chat viewer with message send
- **Settings** — configure bot API URL, connection management
- **OBS Overlay** — browser source overlay (`overlay/index.html`) for stream status bar + alerts

## Project Structure

```
streamer-co-pilot/
├── lib/                  # Flutter app (Dart)
├── service/              # Python/FastAPI bot backend
│   ├── api.py             # FastAPI server (port 8510)
│   ├── alerts/            # Alert management
│   ├── events/            # Event bus
│   ├── integrations/      # StreamElements, etc.
│   ├── requirements.txt   # Python deps
│   └── .env.example       # Copy to .env, fill in credentials
├── overlay/               # OBS browser source overlay
├── packaging/             # NSIS installer, AppImage, Flatpak
├── windows/               # Windows runner (CMake)
├── linux/                 # Linux runner
├── macos/                 # macOS runner
└── .github/workflows/     # CI: build + release (Linux, Windows, macOS)
```

## Quick Start

### 1. Bot Service

```bash
cd service
python -m venv venv

# Windows
source venv/Scripts/activate

# Linux
source venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Edit .env with your Twitch credentials
python api.py
```

The service runs on `http://localhost:8510`.

### 2. Flutter App

```bash
flutter pub get
flutter run -d windows    # or -d linux / -d macos
```

The app auto-detects the service and connects.

## Build a Windows Installer

```bash
# 1. Build the release binary
flutter build windows --release

# 2. Install NSIS (if not already installed)
choco install nsis -y
# or: winget install NSIS.NSIS

# 3. Build the installer
cd packaging/nsis
makensis installer.nsi
```

Output: `packaging/nsis/StreamerCoPilot-Setup.exe`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TWITCH_BOT_PORT` | Backend API port | `8510` |
| `TWITCH_CLIENT_ID` | Twitch app client ID | — |
| `TWITCH_CLIENT_SECRET` | Twitch app secret | — |
| `CHANNEL_NAME` | Twitch channel to monitor | — |
| `STREAMER_COPILOT_PYTHON` | Custom path to Python binary | auto-detected |

## License

MIT — see [LICENSE](LICENSE).