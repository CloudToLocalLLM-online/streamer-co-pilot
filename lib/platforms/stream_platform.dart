import 'dart:async';
import '../models/chat_message.dart';

/// Stream status from any platform.
class StreamStatus {
  final bool live;
  final int viewers;
  final String game;
  final String title;
  final int uptimeSec;

  const StreamStatus({
    this.live = false,
    this.viewers = 0,
    this.game = '',
    this.title = '',
    this.uptimeSec = 0,
  });
}

/// Credentials for a streaming platform.
class PlatformCredentials {
  final String? clientId;
  final String? clientSecret;
  final String? accessToken;
  final String? channelName;
  final String? botId;

  const PlatformCredentials({
    this.clientId,
    this.clientSecret,
    this.accessToken,
    this.channelName,
    this.botId,
  });
}

/// Abstract interface for any streaming platform.
///
/// Implementations: TwitchPlatform, YouTubePlatform, KickPlatform, etc.
abstract class StreamPlatform {
  String get platformName;

  /// Connect to the platform with given credentials.
  Future<bool> connect(PlatformCredentials creds);

  /// Disconnect from the platform.
  Future<void> disconnect();

  /// Whether we're currently connected.
  bool get connected;

  /// Stream of chat messages (realtime).
  Stream<ChatMessage> get chatStream;

  /// Stream of status updates (live/offline, viewers, etc.).
  Stream<StreamStatus> get statusStream;

  /// Send a message to chat.
  Future<bool> sendMessage(String text);

  /// Fetch recent chat messages (for initial load).
  Future<List<ChatMessage>> fetchRecentChat({int count = 30});

  /// Fetch current stream status.
  Future<StreamStatus> fetchStatus();

  // ── Moderation (optional — throws UnsupportedError if not available) ──

  Future<bool> timeoutUser(String user, {int duration = 300});
  Future<bool> banUser(String user);
  Future<bool> unbanUser(String user);
  Future<bool> clearChat();
  Future<bool> setChatMode(String mode, bool enabled);
}
