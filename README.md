<div align="center">

# 🎮 Streamer Co-Pilot

### Your AI co-host for live streaming.

**OBS control · chat awareness · moderation · alerts — driven by an agent that runs on *your* machine.**

[![CI](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/actions/workflows/ci.yml/badge.svg)](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-BSL--1.1-blue)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-289%20passing-brightgreen)](#development)
[![Platforms](https://img.shields.io/badge/platforms-Twitch%20·%20Kick%20·%20YouTube-9146FF)](#streaming-platforms)

**[Download → Releases](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/releases/latest)** · [Quick Start](#quick-start) · [Agent API](#agent-api)

</div>

---

## Why

Streaming is a juggling act: scenes, chat, moderation, timing — while performing for an audience. Streamer Co-Pilot hands the mechanical parts to an AI agent that runs **locally**, under your roof:

> 🗣️ *"Switch to the BRB scene"* — done, hands stay on the game
>
> 💬 *"Anyone asking about the setup?"* — the agent reads live chat and answers
>
> 🛡️ *"Timeout that spammer"* — one sentence instead of six clicks
>
> ⏱️ *"How long have we been live?"* — the agent already knows

No cloud dependency. No subscription. Your agent is the brain — this app is the body.

## What It Does

| | Capability | What you get |
|--|-----------|--------------|
| 🎛️ | **OBS Control** | Scenes, sources, stream/recording, per-channel audio (volume/mute/balance/sync) |
| 💬 | **Chat Awareness** | Real-time merged chat from all platforms, with mod/sub/VIP badges |
| 🔔 | **Alerts** | Subs, resubs, gift subs, raids — animated overlay via OBS browser source |
| 🛡️ | **Moderation** | Timeout / ban / unban / slow mode / emote-only — fans out across platforms |
| 📊 | **Stream Status** | Live state, viewers, game, title — pushed to your agent in real time |
| ⚡ | **Custom Commands** | `!discord`-style commands, managed in-app, executed by the server |
| 🤖 | **Agent Interface** | REST + SSE on `localhost:8511` — ~28 commands, full state grounding |
| 🌐 | **Multistream** | Twitch + Kick + YouTube Live simultaneously |

## How It Works

```
┌───────────────────────────────────────────────┐
│           Streamer Co-Pilot (Flutter)         │
│                                               │
│   OBS Controller      Platform Layer          │
│   obs-websocket       Twitch IRC + Helix      │
│   scenes · audio      Kick websocket          │
│   stream control      YouTube Data API v3     │
│            │                │                 │
│            └───────┬────────┘                 │
│                    ▼                          │
│          Agent Interface                      │
│          localhost:8511 · REST + SSE          │
└────────────────────┬──────────────────────────┘
                     ▼
          ┌─────────────────────┐
          │     Your Agent      │
          │  Hermes · OpenClaw  │
          └─────────────────────┘
```

## Quick Start

1. **Grab a build** — Windows installer or Linux AppImage from [Releases](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/releases/latest)
2. **Connect your stuff** — enable obs-websocket in OBS, authorize Twitch in Settings
3. **Point your agent at `http://localhost:8511`** — it discovers everything via `GET /state`

```bash
curl http://localhost:8511/state | jq .
curl -X POST http://localhost:8511/command \
  -d '{"command": "switch_scene", "params": {"scene": "BRB"}}'
```

> **Hermes Agent users:** install the bundled `streamer-co-pilot` skill and just ask in plain English.

## Agent API

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Liveness check |
| `/state` | GET | Full snapshot — OBS, status, recent chat |
| `/command` | POST | Execute any action |
| `/events/stream` | GET | **SSE**: `platform_status` · `chat_message` · `channel_event` |
| `/overlay` | GET | OBS browser source (status bar + chat + alerts) |
| `/stream/status` | GET | Live / viewers / game / title |
| `/chat/recent` · `/chat/send` | GET/POST | Chat access |
| `/command/list` · `/save` · `/delete` · `/run` | GET/POST | Custom command management |

<details>
<summary><b>Example commands</b></summary>

| Command | Params | Effect |
|---------|--------|--------|
| `switch_scene` | `scene` | Switch OBS scene |
| `toggle_source` / `set_source` | `source`, `enabled?` | Toggle cam/mic/etc. |
| `toggle_stream` / `toggle_recording` | — | Start/stop stream or recording |
| `set_volume` / `set_mute` | `channel`, … | Per-audio-channel control |
| `send_message` | `message` | Send to all connected platforms |
| `timeout` / `ban` / `unban` | `user`, `duration?` | Moderate across platforms |
| `connect_platform` / `disconnect_platform` | `platform`, `channel?` | Hot-connect Twitch/Kick/YouTube |

</details>

Full reference: [docs/AGENT-INTERFACE.md](docs/AGENT-INTERFACE.md)

## Streaming Platforms

| Platform | Chat read | Chat send | Moderation | Status | Auth |
|----------|:---:|:---:|:---:|:---:|------|
| **Twitch** | ✅ | ✅ | ✅ | ✅ | OAuth |
| **Kick** | ✅ | ✅¹ | — | — | None² |
| **YouTube Live** | ✅ | ✅ | — | ✅ | OAuth³ |

<sup>¹ requires a token with `chat:write` scope &nbsp;·&nbsp; ² none needed for reading &nbsp;·&nbsp; ³ youtube.force-ssl scope</sup>

All three run simultaneously through `MultiPlatformManager` — merged chat, broadcast send, moderation fan-out to every platform that supports it.

## App Platforms

| OS | Status |
|----|--------|
| 🪟 Windows | ✅ Installer |
| 🐧 Linux | ✅ AppImage |
| 🍎 macOS | 📋 Planned |

## Development

Requires Flutter (see `pubspec.yaml`).

```bash
git clone https://github.com/CloudToLocalLLM-online/streamer-co-pilot.git
cd streamer-co-pilot
flutter pub get
flutter run -d linux    # or -d windows

# Quality gates (CI enforces)
flutter analyze         # zero issues
flutter test            # 289 tests, all green
```

## Documentation

[Quick Start](docs/user-guide/QUICK-START.md) · [User Guide](docs/user-guide/USER-GUIDE.md) · [Setup](docs/user-guide/SETUP-GUIDE.md) · [Troubleshooting](docs/user-guide/TROUBLESHOOTING.md) · [Architecture](docs/ARCHITECTURE.md) · [Agent Interface](docs/AGENT-INTERFACE.md) · [Platform Integration](docs/PLATFORM-INTEGRATION.md) · [Build Plan](docs/BUILD-PLAN.md)

---

<div align="center">

**BSL 1.1** — © Christopher Maltais · free for internal business use · converts to Apache 2.0 in 2030 · [LICENSE](LICENSE)

*Part of the [CloudToLocalLLM](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM) ecosystem — local-first AI tools.*

</div>
