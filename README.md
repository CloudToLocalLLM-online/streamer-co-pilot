# Streamer Co-Pilot 🎮

**An agent-powered co-pilot for live streamers. OBS control, chat management, stream awareness — all from one desktop app.**

Your Hermes Agent or OpenClaw connects to your stream the same way a human co-host would — it sees what's on screen, reads chat, controls OBS, and talks to your audience. No cloud dependency, no subscription. Runs on your machine.

![Tests](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/actions/workflows/ci.yml/badge.svg)
[![License](https://img.shields.io/badge/license-BSL--1.1-blue)](LICENSE)

---

## Why

Streaming is a juggling act: scenes, chat, moderation, timing — while performing for an audience. Streamer Co-Pilot hands the mechanical parts to an AI agent that runs *locally*, under your roof, with no middleman:

- **"Switch to the BRB scene"** → done, hands stay on the game
- **"Anyone asking about the setup?"** → agent reads live chat and answers
- **"Timeout the spammer in channel"** → one sentence instead of six clicks
- **"We've been live 3 hours"** → the agent notices so you don't have to track time

---

## Try It Now

🪟 **Windows** — Installer from [Releases](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/releases/latest).

🐧 **Linux** — AppImage from [Releases](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/releases/latest).

**You need an agent runtime.** Streamer Co-Pilot is the body — [Hermes Agent](https://hermes-agent.nousresearch.com) or [OpenClaw](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM) is the brain. The app exposes a local API; your agent connects, reads stream context, and acts.

---

## What It Does

| Capability | What it gives you |
|-----------|-------------------|
| **OBS Control** | Switch scenes, toggle cam/mic, start/stop stream & recording, per-channel audio (volume/mute/balance/sync offset) |
| **Chat Awareness** | Real-time chat with mod/sub/VIP badges; your agent knows who's talking |
| **Alerts** | Subs, resubs (with months + message), sub gifts, raids — animated overlay alerts over SSE |
| **Chat Moderation** | Timeout, ban, unban, slow mode, emote-only, sub-only |
| **Stream Status** | Live/offline, viewers, game, title — streamed to agents in real time |
| **OBS Overlay** | Browser source: status bar + chat + animated alerts for your stream |
| **Custom Commands** | `!discord`-style commands managed from the Settings tab, executed by the server |
| **Agent Interface** | REST + SSE on `localhost:8511` — full state grounding, ~28 commands |
| **Multi-Platform** | Twitch today; Kick & YouTube via the platform interface (in progress) |

## How It Works

```
┌─────────────────────────────────────────────────────┐
│              Streamer Co-Pilot (Flutter)             │
│                                                      │
│  ┌─────────────────┐   ┌──────────────────────┐    │
│  │  OBS Controller │   │  Platform Layer      │    │
│  │  obs-websocket  │   │  Twitch IRC + Helix  │    │
│  │  scenes/sources │   │  Kick / YouTube:     │    │
│  │  audio/stream   │   │  pluggable interface │    │
│  └────────┬────────┘   └──────────┬───────────┘    │
│           └───────────┬───────────┘                │
│                       ▼                             │
│           ┌──────────────────────┐                  │
│           │   Agent Interface    │                  │
│           │   localhost:8511     │                  │
│           │   REST + SSE API     │                  │
│           └──────────┬───────────┘                  │
└──────────────────────┼──────────────────────────────┘
                       ▼
           ┌──────────────────────┐
           │      Your Agent      │
           │  (Hermes / OpenClaw) │
           └──────────────────────┘
```

---

## Quick Start

```bash
# Download from Releases, install, launch.
# The app starts an HTTP server on port 8511.
# Your agent connects to http://localhost:8511 and takes over.
```

### What happens when you launch

1. Embedded HTTP server starts on `localhost:8511`
2. OBS auto-connects if saved settings exist (obs-websocket must be enabled)
3. Twitch auto-connects if you've authorized (OAuth flow in Settings)
4. Your agent polls `/state`, grounds itself in context, sends `/command` actions

---

## Agent API

Your agent talks to the app through a simple REST API:

| Endpoint | Method | What it does |
|----------|--------|--------------|
| `GET /health` | GET | Is the app alive? |
| `GET /state` | GET | Full snapshot: OBS state, stream status, recent chat |
| `POST /command` | POST | Execute an action (scenes, sources, audio, chat, moderation) |
| `GET /overlay` | GET | OBS browser source HTML (status bar + chat + alerts) |
| `GET /events/stream` | GET | Server-Sent Events: `platform_status`, `chat_message`, `channel_event` |
| `GET /stream/status` | GET | Live/viewers/game/title |
| `GET /chat/recent?count=N` | GET | Recent chat messages |
| `POST /chat/send` | POST | Send a chat message |
| `GET /command/list` | GET | Custom chat commands |
| `POST /command/save` / `delete` / `run` | POST | Manage custom commands |

Full reference: [docs/AGENT-INTERFACE.md](docs/AGENT-INTERFACE.md). Hermes users: install the bundled `streamer-co-pilot` skill and just ask.

### Example commands

| Command | Params | Effect |
|---------|--------|--------|
| `switch_scene` | `scene` | Switch OBS scene |
| `toggle_source` / `set_source` | `source`, `enabled?` | Toggle cam/mic/etc. |
| `toggle_stream` / `toggle_recording` | — | Start/stop stream or recording |
| `set_volume` / `set_mute` | `channel`, `volume?`/`mute?` | Per-audio-channel control |
| `send_message` | `message` | Send to chat |
| `timeout` / `ban` / `unban` | `user`, `duration?` | Moderate |

```bash
curl http://localhost:8511/state | jq .
curl -X POST http://localhost:8511/command \
  -d '{"command": "switch_scene", "params": {"scene": "BRB"}}'
```

---

## Platforms

**Streaming platforms:** Twitch is fully supported (IRC chat, Helix status, OAuth).
Kick and YouTube Live are next — the codebase already has a clean `StreamPlatform`
interface they plug into.

**App platforms:**

| OS | Status |
|----|--------|
| 🪟 Windows | ✅ Installer |
| 🐧 Linux | ✅ AppImage |
| 🍎 macOS | 📋 Planned |

---

## Development

Requires Flutter (see `pubspec.yaml` for the SDK constraint).

```bash
git clone https://github.com/CloudToLocalLLM-online/streamer-co-pilot.git
cd streamer-co-pilot
flutter pub get

flutter run -d linux    # or -d windows

# Build
flutter build linux --release
flutter build windows --release
```

### Quality gates (CI enforces these)

```bash
flutter analyze        # zero issues required
flutter test           # 269 tests, all green
```

CI runs analyze + tests + Windows/Linux release builds on every push to main.

---

## Documentation

| Guide | What's in it |
|-------|--------------|
| [Quick Start](docs/user-guide/QUICK-START.md) | Get running in 5 minutes |
| [User Guide](docs/user-guide/USER-GUIDE.md) | All features explained |
| [Setup Guide](docs/user-guide/SETUP-GUIDE.md) | Detailed configuration |
| [Troubleshooting](docs/user-guide/TROUBLESHOOTING.md) | Common issues and fixes |
| [Architecture](docs/ARCHITECTURE.md) | System design and components |
| [Agent Interface](docs/AGENT-INTERFACE.md) | Full API reference for agent integration |
| [Platform Integration](docs/PLATFORM-INTEGRATION.md) | Twitch OAuth, IRC, Helix setup |
| [Build Plan](docs/BUILD-PLAN.md) | Development roadmap |

---

## License

Business Source License 1.1 — see [LICENSE](LICENSE).

© Christopher Maltais. Free for internal business use. Commercial hosting as a service requires a license. Converts to Apache 2.0 on 2030-06-03.

---

*Streamer Co-Pilot is part of the [CloudToLocalLLM](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM) ecosystem — local-first AI tools for [Hermes Agent](https://hermes-agent.nousresearch.com) and [OpenClaw](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM).*
