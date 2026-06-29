# Build Plan — Streamer Co-Pilot

## Phase 1: Foundation ✅ (Done)

- [x] Remove Python `service/` directory
- [x] Remove `overlay/index.html` (now embedded in Flutter)
- [x] Archive `streamer-co-pilot-service` repo
- [x] Clean `.gitignore`, README, settings references
- [x] Define `StreamPlatform` abstract interface
- [x] Create `ObsController` provider (obs_websocket)
- [x] Create `AgentServer` provider (shelf HTTP server)
- [x] Add dependencies: `obs_websocket`, `shelf`, `shelf_router`
- [x] Write architecture docs

## Phase 2: Platform Layer ✅ (Done)

### StreamPlatform Interface ✅
Abstract contract in `lib/platforms/stream_platform.dart`. Every platform implements:
- `connect(credentials)` / `disconnect()` / `connected`
- `chatStream` / `statusStream` — real-time event streams
- `sendMessage(text)` / `fetchRecentChat(count)` / `fetchStatus()`
- Moderation: `timeoutUser`, `banUser`, `unbanUser`, `clearChat`, `setChatMode`

### TwitchPlatform ✅
| File | Purpose |
|------|---------|
| `lib/platforms/twitch_platform.dart` | Main class implementing `StreamPlatform` |
| `lib/platforms/twitch_auth.dart` | OAuth token lifecycle (generate URL, exchange code, refresh, store) |
| `lib/platforms/twitch_irc_client.dart` | IRC connection, message parsing, capability negotiation |
| `lib/platforms/twitch_helix_client.dart` | Helix REST API wrapper (status, moderation, users) |

**OAuth Flow:**
1. User clicks "Connect to Twitch" in Settings
2. App opens browser to `https://id.twitch.tv/oauth2/authorize` with scopes
3. User authorizes → Twitch redirects to `http://localhost:8511/auth/callback`
4. App exchanges code for access token + refresh token
5. Tokens stored in SharedPreferences
6. Refresh token used when access token expires (~4h lifetime)

**IRC Details:**
- Server: `irc.chat.twitch.tv:6697` (TLS)
- Auth: `PASS oauth:<token>`, `NICK <bot_username>`
- Capabilities: `twitch.tv/membership twitch.tv/tags twitch.tv/commands`
- Rate limit: 20 messages per 30 seconds

**Helix Endpoints:**
- `GET /helix/streams` — stream status (poll 30s)
- `GET /helix/users` — user ID resolution
- `POST /helix/moderation/bans` — ban
- `POST /helix/moderation/timeouts` — timeout
- `PATCH /helix/chat/settings` — slow/emote/sub-only

### YouTubePlatform & KickPlatform
Documented in `PLATFORM-INTEGRATION.md` as future work. The interface is ready — implementations come when needed.

## Phase 3: OBS Integration ✅ (Done)

- [x] Connect/disconnect via `obs-websocket`
- [x] Read scenes, sources, stream/record status
- [x] Switch scene, toggle source, start/stop stream/record
- [x] Auto-detect — try `localhost:4455` on launch, show status
- [x] Setup guide — if connection fails, show dialog with OBS WebSocket setup instructions
- [x] Test connection — button in Settings
- [x] Status indicator — Dashboard shows OBS connection at a glance

**obs-websocket is built into OBS Studio 28+** (Tools → WebSocket Server Settings). No plugin to install. The app just needs to guide the user through enabling it.

## Phase 4: Wire Everything Together ✅ (Done)

- [x] Start `AgentServer` on app launch (port 8511)
- [x] Start `ObsController` auto-connect on launch
- [x] Platform selector in Settings tab
- [x] OBS config (host, port, password) in Settings
- [x] Dashboard shows OBS state + stream status + chat
- [x] Twitch OAuth callback handler at `/auth/callback`
- [x] All providers wired in `main.dart`

## Phase 5: Agent Integration

- [ ] Hermes skill for streamer-co-pilot
- [ ] Decision loop: poll `/state`, decide, send `/command`
- [ ] Event-driven mode (WebSocket instead of polling)
- [ ] Alert overlay (donations, follows, subs)

## Phase 6: Polish & Release

- [ ] Widget tests (update existing test for new providers)
- [ ] Unit tests for Twitch IRC, Helix, OBS controller
- [ ] Integration test (OBS + Twitch end-to-end)
- [ ] Windows installer (Inno Setup — done, needs CI verification)
- [ ] Linux AppImage
- [ ] macOS DMG
- [ ] CI pipeline (release workflow done, needs testing)

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Twitch OAuth complexity | High | Start with simple token, add refresh later |
| IRC rate limits (20/30s) | Medium | Message queue with rate limiter |
| obs_websocket API changes | Low | Pinned version in pubspec |
| Scope creep (too many platforms) | Medium | Twitch only for MVP |
| Hermes integration undefined | Medium | Agent interface already defined in docs |
