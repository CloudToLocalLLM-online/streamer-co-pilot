# User Guide

How to use Streamer Co-Pilot day-to-day.

---

## The Interface

The app has three tabs: **Dashboard**, **Chat**, and **Settings**.

### Dashboard

The Dashboard is your command center. It shows:

- **Stream status** — LIVE / OFFLINE / Checking
- **OBS connection** — connected or disconnected, current scene name
- **OBS sources** — chips showing each source (Camera, Mic, Game Capture, etc.) with on/off state
- **Twitch connection** — connected or disconnected
- **Recent chat** — last few messages from chat

### Chat

The Chat tab is your live chat interface:

- **Message list** — scrollable chat with badges (mod, sub, vip, broadcaster)
- **Send message** — type and send chat messages
- **Moderation toolbar** — appears when connected:
  - Slow mode toggle
  - Emote-only toggle
  - Sub-only toggle
  - Clear chat button
- **Long-press a message** — shows moderation options (timeout, ban, unban)

### Settings

The Settings tab is where you configure everything:

- **Streaming Platform** — Twitch credentials, OAuth authorization
- **OBS Studio** — connection config, setup guide
- **Agent Interface** — shows the API endpoint for your agent
- **Legacy Bot Connection** — for backward compatibility

---

## OBS Control

Your agent can control OBS through the API:

| Action | What happens |
|--------|-------------|
| Switch scene | Changes the active scene in OBS |
| Toggle source | Turns a source on/off (cam, mic, overlay) |
| Start/stop stream | Begins or ends your live stream |
| Start/stop recording | Begins or ends a local recording |

The Dashboard reflects all changes in real time.

---

## Chat Moderation

Your agent can moderate chat:

| Action | Effect |
|--------|--------|
| Timeout | Removes a user from chat for 5 minutes |
| Ban | Permanently removes a user from chat |
| Unban | Reverses a ban |
| Slow mode | Limits how often users can send messages |
| Emote-only | Only emotes allowed in chat |
| Sub-only | Only subscribers can chat |

---

## OBS Overlay

The app serves an OBS browser source at `http://localhost:8511/overlay`.

To add it to your stream:

1. In OBS, add a new **Browser** source
2. Set the URL to `http://localhost:8511/overlay`
3. Set width/height to match your stream
4. The overlay shows:
   - **Status bar** — LIVE/OFFLINE indicator, viewer count, stream title
   - **Chat overlay** — scrolling chat messages

The overlay auto-refreshes every 5 seconds.

---

## Compact Overlay Mode

On Linux, you can launch the app in compact overlay mode:

```bash
SCOP_OVERLAY=1 ./streamer-co-pilot
```

This opens a small, always-on-top window with just the chat overlay — useful for monitoring chat while gaming.

---

## Agent Integration

Your Hermes Agent or OpenClaw connects to `http://localhost:8511` and can:

1. **Poll `/state`** every 5-10 seconds to maintain awareness
2. **Decide** based on context (scene changed? chat activity? stream status?)
3. **Send `/command`** to act

Example agent behaviors:
- "Scene changed to BRB — switch back after 60 seconds"
- "Chat asking about the game — respond with the game name"
- "Stream has been live for 3 hours — suggest a break"
- "Viewer count dropped to 0 — switch to end screen"

See the [Agent Interface](../AGENT-INTERFACE.md) for the complete API reference.
