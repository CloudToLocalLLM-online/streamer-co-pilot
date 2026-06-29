# Quick Start Guide

Get Streamer Co-Pilot running in 5 minutes.

---

## 1. Install the App

**Windows:** Download the latest installer from [Releases](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/releases/latest) and run it.

**Linux:** Download the AppImage from [Releases](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/releases/latest), make it executable, and run:

```bash
chmod +x streamer-co-pilot-*.AppImage
./streamer-co-pilot-*.AppImage
```

---

## 2. Launch

When you open the app, three things happen automatically:

1. An **agent server** starts on `http://localhost:8511`
2. The app tries to **connect to OBS** (if OBS is running with WebSocket enabled)
3. The app tries to **connect to Twitch** (if you've previously authorized)

You'll see the **Dashboard** tab with connection status indicators.

---

## 3. Connect OBS

1. Open OBS Studio
2. Go to **Tools → WebSocket Server Settings**
3. Check **Enable WebSocket Server**
4. Leave the default port (`4455`) or set your own
5. Set a password (optional)
6. Click **OK**
7. In Streamer Co-Pilot, go to **Settings → OBS Studio**
8. Enter the same host/port/password
9. Click **Connect OBS**

The Dashboard will show your current scene, sources, and stream status.

---

## 4. Connect Twitch

1. Go to the [Twitch Developer Portal](https://dev.twitch.tv/console/apps)
2. Create a new application
3. Set the OAuth redirect URL to `http://localhost:8511/auth/callback`
4. Copy the **Client ID** and **Client Secret**
5. In Streamer Co-Pilot, go to **Settings → Streaming Platform**
6. Paste your Client ID and Client Secret
7. Enter your channel name
8. Click **Authorize with Twitch**
9. A browser window opens — log in and authorize the app
10. The app auto-connects to Twitch chat

---

## 5. Connect Your Agent

Your Hermes Agent or OpenClaw connects to `http://localhost:8511`:

```bash
# Hermes Agent — add to your config
agent_server: http://localhost:8511

# Or test manually
curl http://localhost:8511/health
curl http://localhost:8511/state
```

The agent can now:
- Read stream state (scene, sources, chat, status)
- Switch scenes, toggle sources, start/stop stream
- Send chat messages, moderate chat
- Read the OBS overlay

---

## What's Next?

- [Full User Guide](USER-GUIDE.md) — all features explained
- [Setup Guide](SETUP-GUIDE.md) — detailed configuration
- [Agent Interface](../AGENT-INTERFACE.md) — complete API reference
- [Troubleshooting](TROUBLESHOOTING.md) — common issues
