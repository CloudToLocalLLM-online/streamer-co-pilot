# Test Plan — Streamer Co-Pilot

## Layers of Testing

```
┌─────────────────────────────────────────────┐
│  Manual / Real-World Tests                  │
│  (OBS, Twitch, AI endpoint)                 │
├─────────────────────────────────────────────┤
│  Integration Tests                          │
│  (providers + platforms together)           │
├─────────────────────────────────────────────┤
│  Widget Tests                               │
│  (UI renders, buttons work, state reflects) │
├─────────────────────────────────────────────┤
│  Unit Tests                                 │
│  (models, parsers, auth, IRC, Helix)        │
└─────────────────────────────────────────────┘
```

---

## Layer 1: Unit Tests

### 1.1 ChatMessage Model
| # | Test | Status |
|---|------|--------|
| 1.1.1 | `ChatMessage.fromJson()` parses all fields correctly | ✅ |
| 1.1.2 | `ChatMessage.fromJson()` handles missing fields with defaults | ✅ |
| 1.1.3 | `ChatMessage.toJson()` produces correct map | ✅ |
| 1.1.4 | Round-trip: toJson → fromJson preserves all values | ✅ |

### 1.2 StreamStatus Model
| # | Test | Status |
|---|------|--------|
| 1.2.1 | Default constructor sets all fields to false/0/empty | ✅ |
| 1.2.2 | Named constructor sets fields correctly | ✅ |

### 1.3 PlatformCredentials
| # | Test | Status |
|---|------|--------|
| 1.3.1 | Default constructor sets all fields to null | ✅ |
| 1.3.2 | Named constructor sets fields correctly | ✅ |

### 1.4 TwitchAuth (OAuth token lifecycle)
| # | Test | Status |
|---|------|--------|
| 1.4.1 | `authorizationUrl` contains correct base URL | ✅ |
| 1.4.2 | `authorizationUrl` includes all required scopes | ✅ |
| 1.4.3 | `authorizationUrl` includes client_id and redirect_uri | ✅ |
| 1.4.4 | `isAuthenticated` returns false before exchange | ✅ |
| 1.4.5 | `isAuthenticated` returns true after successful exchange | ⬜ |
| 1.4.6 | `clearTokens()` resets all state | ✅ |
| 1.4.7 | `ensureValidToken()` returns false when no token | ✅ |
| 1.4.8 | `ensureValidToken()` refreshes when expired | ⬜ |

### 1.5 TwitchIrcClient (message parsing)
| # | Test | Status |
|---|------|--------|
| 1.5.1 | Parse PRIVMSG with tags (mod, sub, vip, broadcaster) | ⬜ |
| 1.5.2 | Parse PRIVMSG without tags | ⬜ |
| 1.5.3 | Parse PRIVMSG with tmi-sent-ts timestamp | ⬜ |
| 1.5.4 | Handle PING → responds with PONG | ⬜ |
| 1.5.5 | Handle malformed line gracefully (no crash) | ⬜ |
| 1.5.6 | Handle empty lines gracefully | ⬜ |
| 1.5.7 | `sendMessage()` sends correct PRIVMSG format | ⬜ |
| 1.5.8 | `sendMessage()` returns false when not connected | ⬜ |

### 1.6 TwitchHelixClient (API calls)
| # | Test | Status |
|---|------|--------|
| 1.6.1 | `resolveUserId()` parses response correctly | ⬜ |
| 1.6.2 | `resolveUserId()` returns null on 404 | ⬜ |
| 1.6.3 | `fetchStreamStatus()` parses live stream response | ⬜ |
| 1.6.4 | `fetchStreamStatus()` returns offline when no stream | ⬜ |
| 1.6.5 | `timeoutUser()` sends correct request body | ⬜ |
| 1.6.6 | `banUser()` sends correct request body | ⬜ |
| 1.6.7 | `unbanUser()` sends correct DELETE request | ⬜ |
| 1.6.8 | `setChatMode()` sends correct PATCH body | ⬜ |
| 1.6.9 | All methods handle HTTP errors gracefully | ⬜ |

### 1.7 ObsController (state management)
| # | Test | Status |
|---|------|--------|
| 1.7.1 | Initial state has `connected=false` | ✅ |
| 1.7.2 | `configure()` updates host/port/password | ✅ |
| 1.7.3 | `disconnect()` resets state to defaults | ✅ |
| 1.7.4 | `dispose()` cleans up timers | ✅ |

### 1.8 AiServer (command routing)
| # | Test | Status |
|---|------|--------|
| 1.8.1 | `buildSnapshot()` returns correct structure | ✅ |
| 1.8.2 | `executeCommand('switch_scene')` routes correctly | ✅ |
| 1.8.3 | `executeCommand('toggle_source')` routes correctly | ✅ |
| 1.8.4 | `executeCommand('set_source')` routes correctly | ✅ |
| 1.8.5 | `executeCommand('toggle_stream')` routes correctly | ✅ |
| 1.8.6 | `executeCommand('toggle_recording')` routes correctly | ✅ |
| 1.8.7 | `executeCommand('send_message')` routes correctly | ✅ |
| 1.8.8 | `executeCommand('timeout')` routes correctly | ✅ |
| 1.8.9 | `executeCommand('ban')` routes correctly | ✅ |
| 1.8.10 | `executeCommand('unknown')` returns error | ✅ |
| 1.8.11 | `executeCommand` with missing params returns error | ✅ |
| 1.8.12 | `executeCommand` when OBS not connected returns error | ✅ |

### 1.9 SseClient
| # | Test | Status |
|---|------|--------|
| 1.9.1 | Parses SSE event:data format correctly | ⬜ |
| 1.9.2 | Skips SSE comment lines (heartbeat) | ⬜ |
| 1.9.3 | `disconnect()` closes client cleanly | ✅ |

---

## Layer 2: Widget Tests

### 2.1 Main App
| # | Test | Status |
|---|------|--------|
| 2.1.1 | App renders Dashboard, Chat, Settings tabs | ✅ |
| 2.1.2 | App title shows "Streamer Co-Pilot" | ✅ |
| 2.1.3 | Overlay mode renders CompactOverlayWindow | ⬜ |

### 2.2 Dashboard Tab
| # | Test | Status |
|---|------|--------|
| 2.2.1 | Shows stream status (LIVE/OFFLINE/Checking) | ⬜ |
| 2.2.2 | Shows stream title when available | ⬜ |
| 2.2.3 | Shows game name and viewer count | ⬜ |
| 2.2.4 | Shows OBS connection status | ⬜ |
| 2.2.5 | Shows OBS scene name when connected | ⬜ |
| 2.2.6 | Shows OBS source chips with enabled/disabled state | ⬜ |
| 2.2.7 | Shows Twitch connection status | ⬜ |
| 2.2.8 | Reconnect button calls `connectSse()` | ⬜ |
| 2.2.9 | Refresh button calls `fetchStatus()` | ⬜ |
| 2.2.10 | Shows recent chat messages | ⬜ |
| 2.2.11 | Shows "No messages yet" when chat empty | ⬜ |

### 2.3 Chat Tab
| # | Test | Status |
|---|------|--------|
| 2.3.1 | Shows chat messages with badges (mod, sub, vip, broadcaster) | ⬜ |
| 2.3.2 | Shows "Chat will appear here" when empty | ⬜ |
| 2.3.3 | Send button sends message via provider | ⬜ |
| 2.3.4 | Text field clears after successful send | ⬜ |
| 2.3.5 | Moderation toolbar visible when connected | ⬜ |
| 2.3.6 | Moderation toolbar hidden when disconnected | ⬜ |
| 2.3.7 | Slow/Emote/Subs toggle chips call `setChatMode()` | ⬜ |
| 2.3.8 | Clear chat button calls `clearChat()` | ⬜ |
| 2.3.9 | Long-press message shows moderation bottom sheet | ⬜ |
| 2.3.10 | Timeout button in bottom sheet works | ⬜ |
| 2.3.11 | Ban button in bottom sheet works | ⬜ |
| 2.3.12 | Unban button in bottom sheet works | ⬜ |

### 2.4 Settings Tab
| # | Test | Status |
|---|------|--------|
| 2.4.1 | Platform dropdown shows Twitch/YouTube/Kick | ⬜ |
| 2.4.2 | Twitch Client ID/Secret fields exist | ⬜ |
| 2.4.3 | Channel Name field exists | ⬜ |
| 2.4.4 | "Authorize with Twitch" button visible when not authenticated | ⬜ |
| 2.4.5 | "Connected to Twitch" shown when authenticated | ⬜ |
| 2.4.6 | "Disconnect Twitch" button shown when authenticated | ⬜ |
| 2.4.7 | OBS host/port/password fields exist | ⬜ |
| 2.4.8 | OBS Connect/Disconnect buttons work | ⬜ |
| 2.4.9 | OBS WebSocket setup guide is displayed | ⬜ |
| 2.4.10 | AI Interface section shows API endpoints | ⬜ |
| 2.4.11 | Legacy Bot URL field exists | ⬜ |
| 2.4.12 | Legacy Connect/Disconnect buttons work | ⬜ |

### 2.5 Error Banner
| # | Test | Status |
|---|------|--------|
| 2.5.1 | Hidden when no error | ⬜ |
| 2.5.2 | Shows error message when present | ⬜ |
| 2.5.3 | Dismiss button clears error | ⬜ |

### 2.6 Connection Indicator
| # | Test | Status |
|---|------|--------|
| 2.6.1 | Shows connected state | ⬜ |
| 2.6.2 | Shows disconnected state | ⬜ |

---

## Layer 3: Integration Tests

### 3.1 Provider Wiring
| # | Test | Status |
|---|------|--------|
| 3.1.1 | All 4 providers initialize without error | ⬜ |
| 3.1.2 | `_startServices()` wires AiServer to ObsController and TwitchPlatform | ⬜ |
| 3.1.3 | AiServer starts HTTP server on port 8511 | ⬜ |
| 3.1.4 | ObsController auto-connects on app launch | ⬜ |
| 3.1.5 | TwitchPlatform auto-connects if tokens exist | ⬜ |

### 3.2 AiServer HTTP Endpoints
| # | Test | Status |
|---|------|--------|
| 3.2.1 | `GET /health` returns 200 with status | ⬜ |
| 3.2.2 | `GET /state` returns full state JSON | ⬜ |
| 3.2.3 | `POST /command` with valid command returns success | ⬜ |
| 3.2.4 | `POST /command` with missing command returns 400 | ⬜ |
| 3.2.5 | `GET /overlay` returns HTML | ⬜ |

### 3.3 TwitchPlatform + TwitchAuth
| # | Test | Status |
|---|------|--------|
| 3.3.1 | `connect()` fails gracefully when no tokens saved | ⬜ |
| 3.3.2 | `connect()` succeeds with valid tokens (mock) | ⬜ |
| 3.3.3 | `disconnect()` cleans up IRC and polling | ⬜ |
| 3.3.4 | Chat stream receives messages from IRC | ⬜ |
| 3.3.5 | Status stream receives updates from Helix poller | ⬜ |

### 3.4 StreamerBotProvider + SseClient
| # | Test | Status |
|---|------|--------|
| 3.4.1 | `connectSse()` checks health first | ⬜ |
| 3.4.2 | SSE events update chat list | ⬜ |
| 3.4.3 | SSE events update stream status | ⬜ |
| 3.4.4 | SSE events trigger alerts | ⬜ |
| 3.4.5 | Auto-reconnect on disconnect | ⬜ |
| 3.4.6 | Exponential backoff caps at 30s | ⬜ |

---

## Layer 4: Manual / Real-World Tests

### 4.1 OBS Connection
| # | Test | Status |
|---|------|--------|
| 4.1.1 | Connect to OBS with default localhost:4455 | ⬜ |
| 4.1.2 | Connect with custom host/port/password | ⬜ |
| 4.1.3 | Auto-reconnect when OBS restarts | ⬜ |
| 4.1.4 | Dashboard shows correct scene list | ⬜ |
| 4.1.5 | Dashboard shows correct source list with enabled/disabled | ⬜ |
| 4.1.6 | Dashboard shows stream/record status | ⬜ |
| 4.1.7 | Switch scene via AI command | ⬜ |
| 4.1.8 | Toggle source visibility via AI command | ⬜ |
| 4.1.9 | Start/stop stream via AI command | ⬜ |
| 4.1.10 | Start/stop recording via AI command | ⬜ |
| 4.1.11 | Disconnect and reconnect works | ⬜ |

### 4.2 Twitch Connection
| # | Test | Status |
|---|------|--------|
| 4.2.1 | OAuth flow: click Authorize → browser opens → callback handled | ⬜ |
| 4.2.2 | Tokens persist across app restart | ⬜ |
| 4.2.3 | Token refresh when expired | ⬜ |
| 4.2.4 | IRC connects and receives chat messages | ⬜ |
| 4.2.5 | Send message to chat | ⬜ |
| 4.2.6 | Timeout user works | ⬜ |
| 4.2.7 | Ban user works | ⬜ |
| 4.2.8 | Unban user works | ⬜ |
| 4.2.9 | Stream status polling shows live/offline | ⬜ |
| 4.2.10 | Disconnect and reconnect works | ⬜ |

### 4.3 AI Interface
| # | Test | Status |
|---|------|--------|
| 4.3.1 | `curl http://localhost:8511/health` returns OK | ⬜ |
| 4.3.2 | `curl http://localhost:8511/state` returns JSON | ⬜ |
| 4.3.3 | `curl -X POST http://localhost:8511/command` with scene switch works | ⬜ |
| 4.3.4 | OBS overlay at `http://localhost:8511/overlay` renders in browser | ⬜ |
| 4.3.5 | Overlay auto-refreshes every 5s | ⬜ |

### 4.4 Installer
| # | Test | Status |
|---|------|--------|
| 4.4.1 | NSIS installer runs without UAC errors | ⬜ |
| 4.4.2 | App installs to Program Files | ⬜ |
| 4.4.3 | Desktop shortcut created | ⬜ |
| 4.4.4 | Start Menu shortcut created | ⬜ |
| 4.4.5 | App launches from shortcut | ⬜ |
| 4.4.6 | Uninstaller removes all files and shortcuts | ⬜ |
| 4.4.7 | Add/Remove Programs entry exists | ⬜ |

### 4.5 Cross-Platform
| # | Test | Status |
|---|------|--------|
| 4.5.1 | Linux AppImage builds and runs | ⬜ |
| 4.5.2 | Linux Flatpak builds and runs | ⬜ |
| 4.5.3 | macOS DMG builds and runs | ⬜ |
| 4.5.4 | Overlay mode on Linux (`SCOP_OVERLAY=1`) | ⬜ |

---

## Priority Order

### Phase 1 — Foundation (do first)
- 1.1 ChatMessage model
- 1.2 StreamStatus model
- 1.3 PlatformCredentials
- 1.7 ObsController state
- 1.8 AiServer command routing
- 1.9 SseClient parsing

### Phase 2 — Twitch Core
- 1.4 TwitchAuth
- 1.5 TwitchIrcClient parsing
- 1.6 TwitchHelixClient (with HTTP mocking)

### Phase 3 — Widgets
- 2.1–2.6 All widget tests

### Phase 4 — Integration
- 3.1 Provider wiring
- 3.2 AiServer HTTP
- 3.3 TwitchPlatform
- 3.4 StreamerBotProvider

### Phase 5 — Real World
- 4.1–4.5 Manual tests

---

## Test Infrastructure Needed

| Tool | Purpose | Status |
|------|---------|--------|
| `flutter_test` | Widget + unit tests | ✅ Built-in |
| `mockito` / `mocktail` | Mock HTTP, WebSocket, SharedPreferences | ⬜ |
| `http_mock_adapter` | Mock HTTP responses for Helix tests | ⬜ |
| `fake_async` | Test timers, polling, reconnection | ⬜ |
| `integration_test` | Full app integration tests | ⬜ |
