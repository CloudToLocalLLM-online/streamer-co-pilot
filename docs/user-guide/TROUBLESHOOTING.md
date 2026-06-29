# Troubleshooting

Common issues and how to fix them.

---

## App Won't Start

| Symptom | Cause | Fix |
|---------|-------|-----|
| App crashes on launch | Missing dependencies | Install [Visual C++ Redistributable](https://aka.ms/vcredist) (Windows) |
| App opens then closes | Port 8511 already in use | Kill the process using port 8511: `netstat -ano | findstr :8511` then `taskkill /PID <pid>` |
| "Failed to load" error | Corrupt installation | Reinstall from the latest release |

---

## OBS Connection Issues

### "Only ws:// and wss:// schemes are supported"

The app was connecting without the `ws://` prefix. This is fixed in the latest version — update to the newest release.

### Connection Drops Repeatedly

OBS WebSocket auto-reconnect is built in with a 10-second delay. If it keeps dropping:

1. Check your network connection
2. Make sure OBS isn't closing the WebSocket server
3. Try setting a password (some OBS versions have issues with empty passwords)
4. Check OBS logs: **Help → Log Files → View Current Log**

### OBS Shows "Disconnected" but OBS is Running

1. Verify OBS WebSocket is enabled: **Tools → WebSocket Server Settings**
2. Check the port matches (default: 4455)
3. Restart OBS
4. Click **Connect OBS** again in Settings

---

## Twitch Connection Issues

### "Enter your Twitch Client ID and Secret first"

You need to create a Twitch application:

1. Go to [Twitch Developer Portal](https://dev.twitch.tv/console/apps)
2. Register a new application
3. Set redirect URI to `http://localhost:8511/auth/callback`
4. Copy Client ID and Client Secret into the app

### Browser Opens but Shows Error

The OAuth redirect URI must match **exactly**:

```
http://localhost:8511/auth/callback
```

Not `https`, not a different port, not missing `/auth/callback`.

### "Authorization failed" After Logging In

1. Check your Client ID and Client Secret are correct
2. Make sure the redirect URI in your Twitch app matches exactly
3. Try clearing tokens and re-authorizing:
   - In Settings, click **Disconnect Twitch**
   - Close and reopen the app
   - Click **Authorize with Twitch** again

### Chat Not Appearing

1. Check the connection indicator shows "Connected"
2. If disconnected, go to Settings and re-authorize
3. Make sure your channel name is correct (case-insensitive)
4. Some channels require you to be a moderator to read chat

### "Token expired" Messages

Twitch access tokens expire after ~4 hours. The app should auto-refresh, but if it doesn't:

1. Go to Settings
2. Click **Disconnect Twitch**
3. Click **Authorize with Twitch** again

---

## Agent Connection Issues

### Agent Can't Connect to localhost:8511

1. Make sure the app is running
2. Check the port: `curl http://localhost:8511/health`
3. If connection refused, the app may have crashed — restart it
4. Check for firewall blocking localhost traffic (unusual but possible)

### Agent Gets Empty State

If `/state` returns empty or missing data:

1. OBS data missing → OBS not connected (see OBS section)
2. Chat data missing → Twitch not connected (see Twitch section)
3. All data missing → app just started, wait a few seconds for services to initialize

### Agent Commands Not Working

| Command | If it fails | Check |
|---------|------------|-------|
| `switch_scene` | Returns "OBS not connected" | Connect OBS first |
| `toggle_source` | Returns "OBS not connected" | Connect OBS first |
| `send_message` | Returns "Failed" | Connect Twitch first |
| `timeout`/`ban` | Returns "Failed" | You need moderator permissions on the channel |

---

## Overlay Issues

### Overlay Shows "Connecting..." Forever

1. Make sure the app is running
2. Check the overlay URL: `http://localhost:8511/overlay`
3. The overlay polls `/state` every 5 seconds — if the app is running, it should work
4. In OBS, try refreshing the browser source

### Overlay Not Updating

The overlay auto-refreshes every 5 seconds. If it's stuck:

1. Right-click the browser source in OBS
2. Click **Refresh**

---

## Installer Issues

### "Windows protected your PC" (SmartScreen)

This is a new unsigned installer. To run it:

1. Click **More info**
2. Click **Run anyway**

We're working on code signing for future releases.

### Installer Fails with "Access Denied"

The installer runs at the user level (no admin required). If it fails:

1. Make sure you're installing to a location you have write access to
2. Try running the installer as administrator
3. Check if antivirus is blocking it

---

## Getting Help

If you can't find your issue here:

- **Open an issue** on [GitHub](https://github.com/CloudToLocalLLM-online/streamer-co-pilot/issues)
- **Check the logs** — the app prints debug logs to the console (run from terminal to see them)
- **Include** your app version, OS, OBS version, and what you were doing when the issue occurred
