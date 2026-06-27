# AI Interface — Contract Between App and Hermes

The app exposes a local HTTP API on port **8511**. Hermes (or any Aigent) connects here to read stream state and send commands.

## Base URL

```
http://localhost:8511
```

## Endpoints

### `GET /state` — Full Context Snapshot

Returns everything the AI needs to understand the current stream situation.

```json
{
  "obs": {
    "connected": true,
    "current_scene": "Gaming",
    "scenes": ["Gaming", "BRB", "Just Chatting", "End Screen"],
    "streaming": true,
    "recording": false,
    "stream_duration_sec": 7452,
    "sources": [
      { "name": "Camera", "enabled": true },
      { "name": "Mic/Aux", "enabled": true },
      { "name": "Game Capture", "enabled": true },
      { "name": "Alert Box", "enabled": true }
    ]
  },
  "platform": {
    "connected": true
  },
  "chat": {
    "total_messages": 142,
    "recent": [
      "Viewer42: !uptime",
      "CoolGuy: hello",
      "StreamerBot: @Viewer42 Stream has been live for 2h04m"
    ]
  }
}
```

### `POST /command` — Execute an Action

Send a command. The app routes it to OBS or the platform.

**Request body:**
```json
{
  "command": "switch_scene",
  "params": {
    "scene": "BRB"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Switched to BRB"
}
```

### Available Commands

#### OBS Commands

| Command | Params | Description |
|---------|--------|-------------|
| `switch_scene` | `scene: string` | Switch to a scene |
| `toggle_source` | `source: string` | Toggle a source on/off |
| `set_source` | `source: string, enabled: bool` | Set source state explicitly |
| `toggle_stream` | — | Start/stop streaming |
| `toggle_recording` | — | Start/stop recording |

#### Chat Commands

| Command | Params | Description |
|---------|--------|-------------|
| `send_message` | `message: string` | Send a chat message |
| `timeout` | `user: string` | Timeout user (5 min) |
| `ban` | `user: string` | Ban user |

### `GET /health` — Liveness Check

```json
{
  "status": "ok",
  "obs_connected": true
}
```

### `GET /overlay` — OBS Browser Source

Returns an HTML page designed for OBS browser source. Shows stream status bar + scrolling chat. Polls `/state` every 5s.

## How Hermes Uses This

1. **Poll `/state`** every 5-10s to maintain awareness
2. **Decide** based on context (scene changed? chat activity? stream status?)
3. **Send `/command`** to act
4. **Listen for events** (future: WebSocket for real-time push)

## Future

- **WebSocket endpoint** (`/ws`) for real-time event push instead of polling
- **Event types:** chat message, scene change, stream start/stop, donation, follow, sub
- **AI suggestions** — the app can proactively suggest actions based on context
