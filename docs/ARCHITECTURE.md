# Streamer Co-Pilot — Architecture

## Philosophy

Streamer Co-Pilot is **not a standalone product.** It's a **body for an AI** — a Flutter desktop app that gives Hermes (or any Aigent) the ability to see, hear, and act in a live stream.

The app is the **sensors and actuators**. The AI is the **brain**. They communicate over a local HTTP API.

## Three Layers

```
┌──────────────────────────────────────────────────┐
│  Streamer Co-Pilot (Flutter)                     │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  OBS Controller (obs_websocket)         │   │
│  │  → scenes, sources, cam/mic toggle      │   │
│  │  → streaming/recording control           │   │
│  │  → audio levels, transitions             │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Platform Abstraction                    │   │
│  │  ┌─────────┐ ┌──────────┐ ┌────────┐   │   │
│  │  │ Twitch  │ │ YouTube  │ │  Kick  │ ...│   │
│  │  │ IRC +   │ │ Live API │ │  API   │   │   │
│  │  │ Helix   │ │          │ │        │   │   │
│  │  └─────────┘ └──────────┘ └────────┘   │   │
│  │  Common interface: chat, status, mod    │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Agent Server (port 8511)                   │   │
│  │  → GET /state — full context snapshot    │   │
│  │  → POST /command — execute action        │   │
│  │  → GET /overlay — OBS browser source     │   │
│  └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
         │                              │
         │ obs-websocket                │ HTTP
         ▼                              ▼
┌──────────────┐              ┌──────────────────┐
│  OBS Studio  │              │  Hermes / OpenClaw │
│  (streaming) │              │  (the agent brain)  │
└──────────────┘              └──────────────────┘
```

## Data Flow

1. **OBS Controller** polls OBS every 3s via `obs-websocket` → stores state in `ObsState`
2. **Platform** connects to Twitch/YouTube/Kick → streams chat messages + status updates
3. **Agent Server** reads both providers → builds a unified state snapshot
4. **Hermes** polls `GET /state` or receives events → decides what to do
5. **Hermes** sends `POST /command` → Agent Server routes to OBS or Platform

## State Management

All state lives in `ChangeNotifier` providers (Provider package):

| Provider | Responsibility |
|----------|---------------|
| `StreamerBotProvider` | Legacy — bot URL, chat buffer, commands, alerts. Will be refactored. |
| `ObsController` | OBS connection, scene/source state, stream/record status |
| `AgentServer` | HTTP server, command routing, state snapshot building |

## Key Design Decisions

- **Flutter-only.** No Python backend. The embedded HTTP server (`shelf`) handles overlay serving and AI communication.
- **Platform-agnostic.** The `StreamPlatform` abstract class defines the contract. Each platform is a separate Dart file implementing that contract.
- **Local-first.** Everything runs on localhost. No cloud dependency. The AI connects via local HTTP.
- **OBS is optional.** The app works without OBS — chat and stream status still function. OBS control is additive.
