---
name: streamer-co-pilot
description: "Hermes skill for controlling Streamer Co-Pilot via its local REST + SSE API. Enables agents to read stream state, send commands to OBS/Twitch, and react to live events."
version: 1.0.0
author: Streamer Co-Pilot Team
license: MIT
platforms: [linux, macos, windows]
tags: [streamer-co-pilot, obs, twitch, streaming, agent, automation]
metadata:
  hermes:
    tags: [streamer-co-pilot, obs, twitch, streaming, agent, automation]
    homepage: https://github.com/CloudToLocalLLM-online/streamer-co-pilot
    related_skills: []
---

# Streamer Co-Pilot Agent Skill

This skill teaches Hermes agents how to integrate with **Streamer Co-Pilot** — a Flutter desktop app that exposes a local HTTP API (port 8511) for OBS control, Twitch chat management, and real-time stream events via SSE.

## Quick Start

1. **Start Streamer Co-Pilot** — Launch the app and connect to OBS (Settings → OBS) and Twitch (Settings → Twitch).
2. **Start the Agent Server** — In the app, enable "Agent Interface" → "Start Agent Server" (default: `http://localhost:8511`).
3. **Use this skill** — The agent can now call the tools below to read state and send commands.

## API Overview

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Liveness check |
| `/state` | GET | Full stream state snapshot |
| `/command` | POST | Execute an action (OBS, chat) |
| `/events/stream` | GET (SSE) | Real-time event stream |
| `/overlay` | GET | OBS browser source HTML |

## Tools Provided by This Skill

### `scp_health_check` — Check Server Availability
```yaml
description: "Verify the Streamer Co-Pilot AgentServer is running and healthy."
returns: "{ healthy: bool, obs_connected: bool }"
```

### `scp_get_state` — Get Full Stream State
```yaml
description: "Fetch the complete state snapshot: OBS scenes/sources, streaming status, platform connection, recent chat."
returns: "AgentState object (see schema below)"
```

### `scp_send_command` — Execute a Command
```yaml
description: "Send a command to OBS or Twitch chat."
params:
  command: "string (see command catalog below)"
  params: "object (command-specific parameters)"
returns: "CommandResult { success: bool, message?: string }"
```

### `scp_subscribe_events` — Subscribe to Real-Time Events (SSE)
```yaml
description: "Open an SSE connection to receive live events: chat_message, obs_state, platform_status, channel_event."
returns: "Stream of SseEvent { eventType: string, data: object }"
```

## Command Catalog

### OBS Commands
| Command | Parameters | Description |
|---------|------------|-------------|
| `switch_scene` | `{ scene: string }` | Switch to a scene by name |
| `toggle_source` | `{ source: string }` | Toggle a source on/off |
| `set_source` | `{ source: string, enabled: bool }` | Explicitly enable/disable a source |
| `toggle_stream` | `{}` | Start or stop streaming |
| `toggle_recording` | `{}` | Start or stop recording |

### Chat Commands
| Command | Parameters | Description |
|---------|------------|-------------|
| `send_message` | `{ message: string }` | Send a chat message |
| `timeout` | `{ user: string }` | Timeout a user (5 min) |
| `ban` | `{ user: string }` | Ban a user |

## AgentState Schema

```dart
class AgentState {
  // OBS
  final bool obsConnected;
  final String? currentScene;
  final List<String> scenes;
  final bool streaming;
  final bool recording;
  final int streamDurationSec;
  final List<ObsSource> sources;
  final List<AudioChannel> audioChannels;

  // Platform (Twitch/YouTube/Kick)
  final bool platformConnected;

  // Chat
  final int chatMessageCount;
  final List<String> recentChatPreview; // Last 10 messages
}
```

## SSE Event Types

| Event Type | Data Payload | Description |
|------------|--------------|-------------|
| `chat_message` | `{ user: string, message: string, badges: object[] }` | New chat message |
| `obs_state` | `{ connected: bool, current_scene: string, streaming: bool }` | OBS state change |
| `platform_status` | `{ connected: bool }` | Platform connect/disconnect |
| `channel_event` | `{ type: string, user: string, ... }` | Follow, sub, raid, donation |

## Decision Loop Pattern (Reference Implementation)

The `lib/agent/decision_loop.dart` in the Streamer Co-Pilot repo provides a ready-to-use decision loop:

```dart
// Poll /state, evaluate rules, send /command
final client = AgentClient(baseUrl: 'http://localhost:8511');
final loop = DecisionLoop(
  client: client,
  config: DecisionLoopConfig(
    pollInterval: Duration(seconds: 5),
    rules: defaultRules(), // auto-start stream, scene switching, chat commands
    onLog: print,
  ),
);
await loop.start();
```

### Built-in Rules
- **auto_start_stream** — Starts streaming when platform + OBS are ready and not already streaming
- **switch_to_starting_scene** — Switches to "Starting" scene when going live
- **chat_game_command** — Switches to "Gaming" scene when chat says `!game`
- **chat_mute_command** — Mutes microphone when chat says `!mute`
- **welcome_new_viewer** — Sends welcome message (use carefully — spam risk)

## Integration Example (Hermes Agent)

```markdown
# In your Hermes session or bot config

## Streamer Co-Pilot Agent
- **Server**: http://localhost:8511
- **Poll interval**: 5s (or use SSE for real-time)
- **Capabilities**: OBS scene control, Twitch chat moderation, stream automation

## Sample Agent Prompt
"You are a stream co-pilot. Monitor the stream state via Streamer Co-Pilot.
- When the streamer goes live, switch to the 'Starting' scene.
- If chat says '!brb', switch to 'BRB' scene and mute mic.
- If chat says '!game', switch to 'Gaming' scene.
- Moderate chat: timeout spammers, ban toxic users.
- Announce new followers/subs in chat."
```

## Installation

### As a Project Skill (Recommended)
Copy this file to your Hermes skills directory:
```bash
cp skills/streamer-co-pilot.md ~/.hermes/skills/streamer-co-pilot.md
# Or for a specific profile:
cp skills/streamer-co-pilot.md ~/.hermes/profiles/<profile>/skills/streamer-co-pilot.md
```

### As a Global Skill (All Profiles)
```bash
hermes skill install /path/to/streamer-co-pilot/skills/streamer-co-pilot.md
```

## Verification

After installation, verify the skill loads:
```bash
hermes skill list | grep streamer-co-pilot
```

Test the API manually:
```bash
curl http://localhost:8511/health
curl http://localhost:8511/state | jq
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused | Ensure Streamer Co-Pilot is running and Agent Server is started in Settings |
| 404 on `/command` | Check command name spelling; see Command Catalog above |
| SSE disconnects | SSE runs on port 8512 (8511 + 1); check firewall |
| OBS commands fail | Verify OBS WebSocket is connected in Streamer Co-Pilot Settings |
| Twitch commands fail | Verify Twitch is authenticated and connected in Settings |

## Related Files

- `docs/AGENT-INTERFACE.md` — Full API contract
- `lib/agent/agent_client.dart` — Dart HTTP + SSE client
- `lib/agent/decision_loop.dart` — Reusable decision loop with built-in rules
- `lib/agent/agent_main.dart` — Standalone agent runner (`dart run lib/agent/agent_main.dart`)
- `test/agent/agent_test.dart` — Unit tests for client, state parsing, decision loop