# Streamer Co-Pilot 🎮

A Flutter desktop app that gives an AI (Hermes, Aigent, etc.) the ability to see, hear, and act in a live stream.

**This is not a standalone product.** It's a **body** for an AI — sensors (OBS state, chat, stream status) and actuators (switch scenes, toggle cam/mic, send chat, trigger alerts). The AI connects via a simple API, reads the context, and sends commands.

## Architecture

```
┌──────────────────────────────────────────┐
│  Streamer Co-Pilot (Flutter)             │
│                                          │
│  ┌──────────┐  ┌──────────┐            │
│  │ OBS Ctrl │  │ Platform │            │
│  │ (senses  │  │ (chat +  │            │
│  │  + acts) │  │  status) │            │
│  └──────────┘  └──────────┘            │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  AI Interface (HTTP/WebSocket)   │   │
│  │  → Hermes/Aigent connects here   │   │
│  │  → reads state, sends commands   │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  Hermes / Aigent (the AI)               │
│  → "Scene changed, switch back?"        │
│  → "Chat asking, respond"               │
│  → "Stream 3h, suggest break"           │
└──────────────────────────────────────────┘
```

## Features

- **OBS Control** — scenes, sources, cam/mic toggle, audio, recording/streaming
- **Multi-platform chat** — Twitch, YouTube Live, Kick (extensible)
- **Stream status** — live/offline, viewers, game, title, uptime
- **Moderation** — timeout, ban, unban, slow/emote/sub-only modes
- **Alerts** — donations, follows, subs, raids with visual + TTS
- **OBS Overlay** — browser source for alerts + chat overlay
- **AI Interface** — REST API + WebSocket for AI agents to connect

## Project Structure

```
streamer-co-pilot/
├── lib/
│   ├── main.dart                  # Entry point + overlay mode
│   ├── providers/                 # State management
│   │   ├── streamer_bot_provider.dart  # Central state
│   │   ├── obs_controller.dart         # OBS websocket control
│   │   └── ai_server.dart              # HTTP server for AI
│   ├── models/                    # Data models
│   ├── platforms/                 # Platform abstractions
│   │   ├── stream_platform.dart       # Abstract interface
│   │   ├── twitch_platform.dart        # Twitch impl
│   │   └── ...
│   ├── services/                  # Low-level clients
│   │   ├── sse_client.dart            # SSE event stream
│   │   └── obs_client.dart            # OBS websocket client
│   ├── tabs/                      # UI tabs
│   │   ├── dashboard_tab.dart
│   │   ├── chat_tab.dart
│   │   └── settings_tab.dart
│   ├── widgets/                   # Reusable widgets
│   └── theme/                     # Dark theme
├── overlay/                       # OBS browser source HTML
├── packaging/                     # Installers
└── .github/workflows/             # CI
```

## Quick Start

```bash
flutter pub get
flutter run -d windows
```

The app starts an embedded HTTP server (port 8511) for the OBS overlay and AI interface.

## AI API

The app exposes a REST API at `http://localhost:8511`:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/state` | GET | Full stream + OBS state snapshot |
| `/command` | POST | Send a command (switch scene, toggle cam, send chat, etc.) |
| `/events` | GET | SSE stream of real-time events |

## License

MIT — see [LICENSE](LICENSE).
