# Setup Guide

Detailed setup instructions for Streamer Co-Pilot.

---

## Prerequisites

- **Windows 10/11** or **Linux** (x86_64)
- **OBS Studio 28+** (optional, for OBS control)
- **A Twitch account** (optional, for chat)
- **Hermes Agent** or **OpenClaw** (optional, for agent features)

---

## OBS WebSocket Setup

Streamer Co-Pilot controls OBS through the built-in WebSocket server (OBS Studio 28+).

### Step-by-Step

1. **Open OBS Studio**
2. Go to **Tools → WebSocket Server Settings**
3. Check **Enable WebSocket Server**
4. **Port:** `4455` (default) — change if you have a conflict
5. **Password:** Set one for security (optional but recommended)
6. Click **OK**

### In Streamer Co-Pilot

1. Go to **Settings → OBS Studio**
2. **Host:** `localhost` (or the IP of your OBS machine)
3. **Port:** `4455` (match what you set in OBS)
4. **Password:** Enter if you set one
5. Click **Connect OBS**

The status indicator should turn green and show your current scene.

### Troubleshooting OBS Connection

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "Connection refused" | OBS not running or WebSocket disabled | Enable WebSocket Server in OBS Tools |
| "Connection timeout" | Wrong host/port | Check OBS WebSocket settings match |
| "Authentication failed" | Wrong password | Reset password in OBS WebSocket settings |
| Connection drops | OBS restart or network issue | Auto-reconnect is built in (10s delay) |

---

## Twitch Setup

### Create a Twitch Application

1. Go to the [Twitch Developer Portal](https://dev.twitch.tv/console/apps)
2. Click **Register Your Application**
3. **Name:** `Streamer Co-Pilot` (or anything)
4. **OAuth Redirect URL:** `http://localhost:8511/auth/callback`
5. **Category:** Application Integration
6. Click **Create**
7. Copy the **Client ID** (shown on the app page)
8. Click **New Secret** and copy the **Client Secret**

### In Streamer Co-Pilot

1. Go to **Settings → Streaming Platform**
2. **Platform:** Select "Twitch"
3. **Client ID:** Paste from Twitch Developer Portal
4. **Client Secret:** Paste from Twitch Developer Portal
5. **Channel Name:** Your Twitch channel name
6. Click **Authorize with Twitch**
7. A browser window opens — log in to Twitch and authorize
8. The app auto-connects

### What Happens After Authorization

- The app connects to Twitch IRC (real-time chat)
- It polls the Helix API every 30 seconds for stream status
- Tokens are stored securely in the app's local storage
- Tokens auto-refresh when they expire (~4 hours)

### Troubleshooting Twitch

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "Enter your Client ID and Secret" | Fields empty | Fill in credentials from Twitch Developer Portal |
| Browser doesn't open | URL launcher blocked | Manually open the authorization URL shown in logs |
| "Authorization failed" | Wrong redirect URI | Must be exactly `http://localhost:8511/auth/callback` |
| "Not connected" after auth | Token exchange failed | Check Client ID/Secret are correct |
| Chat not appearing | IRC connection issue | Disconnect and reconnect in Settings |

---

## Agent Setup

### Hermes Agent

Add the agent server to your Hermes config:

```yaml
# hermes config.yaml
agent_servers:
  - name: streamer-co-pilot
    url: http://localhost:8511
    poll_interval: 5s
```

Or set it via CLI:

```bash
hermes config set agent_servers.streamer-co-pilot.url http://localhost:8511
```

### OpenClaw

OpenClaw connects automatically when the app is running. The agent server is at `http://localhost:8511`.

### Manual Test

```bash
# Health check
curl http://localhost:8511/health

# Read state
curl http://localhost:8511/state | jq

# Send a command
curl -X POST http://localhost:8511/command \
  -H "Content-Type: application/json" \
  -d '{"command": "switch_scene", "params": {"scene": "BRB"}}'
```

---

## Network Configuration

### Everything Runs Locally

All communication is on `localhost` — nothing leaves your machine:

| Service | Port | Purpose |
|---------|------|---------|
| Agent server | 8511 | Agent API + OBS overlay |
| OBS WebSocket | 4455 | OBS control (OBS Studio) |
| Twitch IRC | 443 (outbound) | Real-time chat |
| Twitch Helix API | 443 (outbound) | Stream status, moderation |

### Firewall

If you're running OBS on a different machine:

1. Allow port `4455` through the OBS machine's firewall
2. In Streamer Co-Pilot, set the OBS host to the remote machine's IP
3. Set a strong password on the OBS WebSocket

---

## Uninstalling

**Windows:** Use Add/Remove Programs → Streamer Co-Pilot.

**Linux:** Delete the AppImage file. Configuration is stored in `~/.config/streamer-co-pilot/`.
