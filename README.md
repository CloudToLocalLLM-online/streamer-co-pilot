# Streamer Co-Pilot 🎮

**An AI-powered co-pilot for live streamers. OBS control, chat management, stream awareness — all from one desktop app.**

Your AI agent connects to your stream the same way a human co-host would — it sees what's on screen, reads chat, controls OBS, and talks to your audience. No cloud dependency, no subscription. Runs on your machine.

---

## Try It Now

🪟 **Windows** — Download the latest installer from [Releases](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/releases/latest).

🐧 **Linux** — AppImage builds from CI. Grab the latest from [Releases](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/releases/latest).

**You need an AI agent.** Streamer Co-Pilot is the body — your AI (Hermes, Aigent, OpenClaw, or any agent that speaks HTTP) is the brain. The app exposes a simple API; your agent connects, reads the stream context, and acts.

---

## What It Does

| Capability | What it gives you |
|-----------|-------------------|
| **OBS Control** | Switch scenes, toggle cam/mic, start/stop stream and recording — all from your AI |
| **Chat Awareness** | Your AI reads chat in real time, knows who's talking, who's mod/sub/vip |
| **Chat Moderation** | Timeout, ban, unban, slow mode, emote-only, sub-only — AI-assisted moderation |
| **Stream Status** | Live/offline, viewer count, game, title, uptime — your AI knows the context |
| **OBS Overlay** | Browser source with live status bar + chat overlay for your stream |
| **AI Interface** | REST API on `localhost:8511` — your agent connects, reads state, sends commands |
| **Multi-Platform** | Twitch (ready), YouTube Live and Kick (extensible interface) |

---

## How It Works

```
┌─────────────────────────────────────────────────────┐
│              Streamer Co-Pilot (Flutter)              │
│                                                       │
│  ┌──────────────────┐   ┌────────────────────────┐  │
│  │   OBS Controller  │   │   Platform Layer       │  │
│  │   scenes, sources, │   │   Twitch IRC + Helix  │  │
│  │   stream, record   │   │   chat, moderation    │  │
│  └────────┬─────────┘   └───────────┬────────────┘  │
│           └──────────┬───────────────┘                │
│                      ▼                                │
│           ┌──────────────────────┐                    │
│           │   AI Interface      │                    │
│           │   localhost:8511    │                    │
│           │   REST + SSE API    │                    │
│           └──────────┬───────────┘                    │
└──────────────────────┼────────────────────────────────┘
                       │
                       ▼
           ┌──────────────────────┐
           │   Your AI Agent      │
           │   (Hermes / Aigent   │
           │    / OpenClaw / ...) │
           │                      │
           │  "Scene changed,     │
           │   switch back?"      │
           │  "Chat asking about  │
           │   the game, respond" │
           │  "Stream 3h,         │
           │   suggest break"     │
           └──────────────────────┘
```

---

## Quick Start

```bash
# Install
winget install --id CloudToLocalLLM.StreamerCoPilot  # Windows (coming soon)
# Or download from Releases

# Launch — the app starts an HTTP server on port 8511
# Your AI connects to http://localhost:8511 and takes over
```

### What happens when you launch

1. App starts → embedded HTTP server on `localhost:8511`
2. OBS auto-connect (if OBS is running with WebSocket enabled)
3. Twitch auto-connect (if you've authorized)
4. Your AI polls `/state`, reads the context, sends `/command` actions

---

## AI API

Your agent talks to the app through a simple REST API:

| Endpoint | Method | What it does |
|----------|--------|-------------|
| `GET /health` | — | Is the app alive? |
| `GET /state` | — | Full snapshot: OBS state, stream status, recent chat |
| `POST /command` | JSON | Execute an action (switch scene, toggle cam, send chat, moderate) |
| `GET /overlay` | — | OBS browser source HTML |

### Commands your AI can send

| Command | Params | Effect |
|---------|--------|--------|
| `switch_scene` | `scene` (string) | Switch OBS to a scene |
| `toggle_source` | `source` (string) | Toggle a source on/off (cam, mic, etc.) |
| `set_source` | `source`, `enabled` (bool) | Enable or disable a source |
| `toggle_stream` | — | Start/stop stream |
| `toggle_recording` | — | Start/stop recording |
| `send_message` | `message` (string) | Send a chat message |
| `timeout` | `user` (string) | Timeout a user (300s) |
| `ban` | `user` (string) | Ban a user |

---

## Platforms

| Platform | Status |
|----------|--------|
| 🪟 Windows | ✅ Installer (Inno Setup) |
| 🐧 Linux | ✅ AppImage + Flatpak |
| 🍎 macOS | 📋 Planned |

---

## Development

```bash
git clone https://github.com/CloudToLocalLLM-online/streamer-co-pilot.git
cd streamer-co-pilot
flutter pub get

# Run
flutter run -d windows   # Windows
flutter run -d linux     # Linux

# Build
flutter build windows --release
flutter build linux --release

# Build installer (Windows — requires Inno Setup 6)
bash scripts/packaging/build_windows_installer.sh
```

### Test

```bash
flutter test        # 149 tests, all pass
flutter analyze     # 0 issues
```

---

## Documentation

| Guide | What's in it |
|-------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | System design and component overview |
| [AI Interface](docs/AI-INTERFACE.md) | Full API reference for agent integration |
| [Platform Integration](docs/PLATFORM-INTEGRATION.md) | Twitch OAuth, IRC, Helix setup |
| [Build Plan](docs/BUILD-PLAN.md) | Development roadmap |
| [Test Plan](docs/TEST-PLAN.md) | Coverage and test strategy |

---

## License

Business Source License 1.1 — see [LICENSE](LICENSE).

© Christopher Maltais. Free for internal business use. Commercial hosting as a service requires a license. Changes to Apache 2.0 on 2030-06-03.

---

*Streamer Co-Pilot is part of the [CloudToLocalLLM](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM) ecosystem — local-first AI tools that run on your hardware.*
