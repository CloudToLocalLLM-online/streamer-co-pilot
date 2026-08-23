import 'dart:async';
import '../models/chat_message.dart';
import 'kick_platform.dart';
import 'stream_platform.dart';
import 'twitch_platform.dart';
import 'youtube_platform.dart';

/// Manages multiple streaming platforms simultaneously.
///
/// Merges chat/status/event streams from every connected platform into
/// single broadcast streams, tagging each item with its platform name.
/// AgentServer consumes these merged streams — same interface as before,
/// just more than one platform underneath.
class MultiPlatformManager extends StreamPlatform {
  final List<StreamPlatform> _platforms = [];
  final _chatController = StreamController<ChatMessage>.broadcast();
  final _statusController = StreamController<StreamStatus>.broadcast();
  final _subscriptions = <StreamSubscription>[];
  StreamStatus? _lastStatus;

  @override
  String get platformName =>
      _platforms.map((p) => p.platformName).join('+');

  @override
  bool get connected => _platforms.any((p) => p.connected);

  @override
  Stream<ChatMessage> get chatStream => _chatController.stream;

  @override
  Stream<StreamStatus> get statusStream => _statusController.stream;

  /// All managed platforms (connected or not).
  List<StreamPlatform> get platforms => List.unmodifiable(_platforms);

  /// Look up a platform by name ('Twitch', 'Kick', 'YouTube').
  T? get<T extends StreamPlatform>() {
    for (final p in _platforms) {
      if (p is T) return p;
    }
    return null;
  }

  /// Register a platform and start merging its streams.
  void add(StreamPlatform platform) {
    if (_platforms.contains(platform)) return;
    _platforms.add(platform);
    _subscriptions.add(platform.chatStream.listen(_chatController.add));
    _subscriptions
        .add(platform.statusStream.listen(_statusController.add));
  }

  /// Connect one registered platform by runtime type name.
  Future<bool> connectPlatform(
      Type platformType, PlatformCredentials creds) async {
    for (final p in _platforms) {
      if (p.runtimeType == platformType) {
        final ok = await p.connect(creds);
        if (ok) {
          p.fetchStatus().then((s) => _statusController.add(s));
        }
        return ok;
      }
    }
    return false;
  }

  @override
  Future<bool> connect(PlatformCredentials creds) async =>
      false; // Use connectPlatform per platform instead.

  @override
  Future<void> disconnect() async {
    for (final p in _platforms) {
      await p.disconnect();
    }
    _statusController.add(const StreamStatus(live: false));
  }

  /// Disconnect a single platform.
  Future<void> disconnectPlatform(Type platformType) async {
    for (final p in _platforms) {
      if (p.runtimeType == platformType) {
        await p.disconnect();
        return;
      }
    }
  }

  @override
  Future<bool> sendMessage(String text) async {
    // Broadcast to every connected platform.
    var anySent = false;
    for (final p in _platforms) {
      if (!p.connected) continue;
      try {
        if (await p.sendMessage(text)) anySent = true;
      } on UnsupportedError {
        continue; // Platform can't send (e.g. Kick without OAuth).
      }
    }
    return anySent;
  }

  @override
  Future<List<ChatMessage>> fetchRecentChat({int count = 30}) async {
    // Merge recent chat from all platforms, newest first.
    final all = <ChatMessage>[];
    for (final p in _platforms) {
      try {
        all.addAll(await p.fetchRecentChat(count: count));
      } catch (_) {}
    }
    all.sort((a, b) => b.time.compareTo(a.time));
    return all.take(count).toList();
  }

  @override
  Future<StreamStatus> fetchStatus() async {
    // Prefer any live platform's status.
    for (final p in _platforms) {
      try {
        final s = await p.fetchStatus();
        if (s.live) {
          _lastStatus = s;
          return s;
        }
      } catch (_) {}
    }
    return _lastStatus ?? const StreamStatus();
  }

  @override
  Future<bool> timeoutUser(String user, {int duration = 300}) async =>
      _moderate((p) => p.timeoutUser(user, duration: duration));

  @override
  Future<bool> banUser(String user) async =>
      _moderate((p) => p.banUser(user));

  @override
  Future<bool> unbanUser(String user) async =>
      _moderate((p) => p.unbanUser(user));

  @override
  Future<bool> clearChat() async =>
      _moderate((p) => p.clearChat());

  @override
  Future<bool> setChatMode(String mode, bool enabled) async =>
      _moderate((p) => p.setChatMode(mode, enabled));

  /// Run a moderation action on all platforms that support it.
  Future<bool> _moderate(
      Future<bool> Function(StreamPlatform) action) async {
    var anyOk = false;
    for (final p in _platforms) {
      if (!p.connected) continue;
      try {
        if (await action(p)) anyOk = true;
      } on UnsupportedError {
        continue;
      }
    }
    return anyOk;
  }

  /// Call this when the manager will no longer be used.
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _chatController.close();
    _statusController.close();
  }
}

/// Convenience factory registering all built-in platforms.
MultiPlatformManager createMultiPlatformManager({
  TwitchPlatform? twitch,
  KickPlatform? kick,
  YoutubePlatform? youtube,
}) {
  final manager = MultiPlatformManager();
  if (twitch != null) manager.add(twitch);
  if (kick != null) manager.add(kick);
  if (youtube != null) manager.add(youtube);
  return manager;
}
