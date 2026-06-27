# Platform Integration Guide

How to add a new streaming platform to Streamer Co-Pilot.

## The Contract

Every platform implements `StreamPlatform` from `lib/platforms/stream_platform.dart`:

```dart
abstract class StreamPlatform {
  String get platformName;
  Future<bool> connect(PlatformCredentials creds);
  Future<void> disconnect();
  bool get connected;
  Stream<ChatMessage> get chatStream;
  Stream<StreamStatus> get statusStream;
  Future<bool> sendMessage(String text);
  Future<List<ChatMessage>> fetchRecentChat({int count = 30});
  Future<StreamStatus> fetchStatus();

  // Moderation (optional — throws UnsupportedError)
  Future<bool> timeoutUser(String user, {int duration = 300});
  Future<bool> banUser(String user);
  Future<bool> unbanUser(String user);
  Future<bool> clearChat();
  Future<bool> setChatMode(String mode, bool enabled);
}
```

## Implementation Steps

1. **Create the file** — `lib/platforms/<name>_platform.dart`
2. **Implement the interface** — all required methods
3. **Handle auth** — OAuth tokens, refresh logic, storage via SharedPreferences
4. **Wire up streams** — `chatStream` and `statusStream` should emit in real-time
5. **Register in Settings** — add to the platform picker dropdown

## Twitch (Reference Implementation)

Twitch is the first and reference platform. It uses:

- **IRC** (`twitch_irc` Dart package) for real-time chat
- **Helix API** (REST) for stream status, moderation, user info
- **OAuth** with `chat:read`, `chat:edit`, `channel:moderate`, `channel:read:stream_key` scopes

Key files:
- `lib/platforms/twitch_platform.dart` — main implementation
- `lib/platforms/twitch_auth.dart` — OAuth token management

## YouTube

YouTube Live uses:
- **YouTube Data API v3** for stream status and chat
- **OAuth 2.0** with `https://www.googleapis.com/auth/youtube` scope
- Polling-based chat (no IRC equivalent)

## Kick

Kick does not have a public API. Integration would require:
- Web scraping or reverse-engineering their WebSocket protocol
- No official moderation API
- Community-maintained Dart packages (if any exist)

## Adding a New Platform Checklist

- [ ] Create `lib/platforms/<name>_platform.dart`
- [ ] Implement all `StreamPlatform` methods
- [ ] Handle connection lifecycle (connect, disconnect, reconnect)
- [ ] Handle token refresh
- [ ] Add to settings UI
- [ ] Test with real credentials
- [ ] Document platform-specific quirks
