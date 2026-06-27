# Build Plan — Streamer Co-Pilot

## Phase 1: Foundation ✅ (Done)

- [x] Remove Python `service/` directory
- [x] Remove `overlay/index.html` (now embedded in Flutter)
- [x] Archive `streamer-co-pilot-service` repo
- [x] Clean `.gitignore`, README, settings references
- [x] Define `StreamPlatform` abstract interface
- [x] Create `ObsController` provider (obs_websocket)
- [x] Create `AiServer` provider (shelf HTTP server)
- [x] Add dependencies: `obs_websocket`, `shelf`, `shelf_router`
- [x] Write architecture docs

## Phase 2: Twitch Integration (Current)

- [ ] Implement `TwitchPlatform` — IRC chat + Helix API
- [ ] OAuth token management (storage, refresh)
- [ ] Wire `chatStream` and `statusStream`
- [ ] Test with real Twitch credentials

## Phase 3: Wire Everything Together

- [ ] Start `AiServer` on app launch
- [ ] Start `ObsController` on app launch (auto-connect to OBS)
- [ ] Platform selector in Settings tab
- [ ] OBS config (host, port, password) in Settings
- [ ] Dashboard shows OBS state + stream status

## Phase 4: AI Integration

- [ ] Hermes skill for streamer-co-pilot
- [ ] Decision loop: poll `/state`, decide, send `/command`
- [ ] Event-driven mode (WebSocket instead of polling)
- [ ] Alert overlay (donations, follows, subs)

## Phase 5: Polish & Release

- [ ] Tests (widget + unit + integration)
- [ ] Windows installer (NSIS)
- [ ] Linux AppImage
- [ ] macOS DMG
- [ ] CI pipeline

## Dependencies Between Phases

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4
                │                        │
                └── Phase 2.5 ───────────┘
                (OBS + Platform
                 both working)
```

Phase 2 (Twitch) and Phase 3 (wiring) can partially overlap — the AI server and OBS controller can be tested independently of Twitch.

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Twitch OAuth complexity | High | Start with a simple token, add refresh later |
| obs_websocket API changes | Low | Pinned version in pubspec |
| Scope creep (too many platforms) | Medium | Twitch only for MVP |
| Hermes integration undefined | Medium | Define AI interface first (done) |
