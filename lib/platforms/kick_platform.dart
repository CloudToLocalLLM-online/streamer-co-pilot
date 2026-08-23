import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/chat_message.dart';
import 'stream_platform.dart';

/// Kick.com platform implementation.
///
/// Chat: Pusher WebSocket (public app key — same one kick.com ships to
/// browsers). Status/chatroom lookup: kick.com/api/v2/channels/{slug}
/// (unofficial, may require browser-like headers; Cloudflare can block
/// server-side requests from datacenter IPs but usually allows desktop apps).
/// Sending messages requires Kick's official OAuth API (api.kick.com,
/// `chat:write` scope) — pass an accessToken via PlatformCredentials to
/// enable sendMessage. Without a token, chat stays read-only.
class KickPlatform extends StreamPlatform with ChangeNotifier {
  final http.Client _http;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  final _chatController = StreamController<ChatMessage>.broadcast();
  final _statusController = StreamController<StreamStatus>.broadcast();

  String? _accessToken;
  int? _broadcasterUserId;

  @override
  String get platformName => 'Kick';

  String? _slug;
  @override
  bool get connected => _ws != null && _slug != null;

  @override
  Stream<ChatMessage> get chatStream => _chatController.stream;

  @override
  Stream<StreamStatus> get statusStream => _statusController.stream;

  KickPlatform({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Resolve a channel slug to its chatroom id via the v2 endpoint.
  Future<int?> fetchChatroomId(String slug) async {
    try {
      final res = await _http.get(
        Uri.parse('https://kick.com/api/v2/channels/$slug'),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final chatroom = data['chatroom'] as Map<String, dynamic>?;
      final id = chatroom?['id'];
      if (id is int) {
        _slug = slug;
        return id;
      }
      if (id is String) {
        _slug = slug;
        return int.tryParse(id);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> connect(PlatformCredentials creds) async {
    final slug = creds.channelName;
    if (slug == null || slug.isEmpty) return false;
    final chatroomId = await fetchChatroomId(slug);
    if (chatroomId == null) return false;

    // Optional OAuth for sending (chat:write scope).
    _accessToken = (creds.accessToken?.isEmpty ?? true) ? null : creds.accessToken;
    if (_accessToken != null) {
      await _resolveBroadcasterId(slug);
    }

    try {
      // Public Pusher app key for kick.com (not a secret).
      const appKey = '32cbd69e4b950bf97679';
      final wsUrl = Uri.parse(
        'wss://ws-us2.pusher.com/app/$appKey'
        '?protocol=7&client=js&version=8.4.0-rc2&flash=false',
      );
      _ws = WebSocketChannel.connect(wsUrl);
      await _ws!.ready.timeout(const Duration(seconds: 10));

      // Subscribe to the channel's chatroom.
      _ws!.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'auth': '', 'channel': 'chatrooms.$chatroomId'},
      }));

      _wsSub = _ws!.stream.listen(
        _onWsMessage,
        onError: (_) => disconnect(),
        onDone: () => disconnect(),
      );
      return true;
    } catch (_) {
      _ws = null;
      return false;
    }
  }

  /// Test hook: parse one Pusher frame, return the ChatMessage if it's chat.
  ChatMessage? parseWsFrameForTest(String raw) => _parseChatEvent(raw);

  void _onWsMessage(dynamic raw) {
    try {
      final msg = _parseChatEvent(raw as String);
      if (msg != null) _chatController.add(msg);
      // pusher_internal:subscription_succeeded and ping/pong are ignored;
      // protocol=7 handles keepalive at the transport level for our needs.
    } catch (_) {
      // Malformed frame — ignore.
    }
  }

  /// Parse a Pusher frame; returns the chat message if it's a
  /// ChatMessageSentEvent, null otherwise (or on malformed input).
  ChatMessage? _parseChatEvent(String raw) {
    try {
      final frame = jsonDecode(raw) as Map<String, dynamic>;
      final event = frame['event'] as String?;
      if (event != r'App\Events\ChatMessageSentEvent') return null;
      final payload =
          jsonDecode(frame['data'] as String? ?? '{}') as Map<String, dynamic>;
      final message = payload['message'] as Map<String, dynamic>?;
      final user = payload['user'] as Map<String, dynamic>?;
      final text = message?['message'] as String?;
      final username = user?['username'] as String?;
      if (text == null || username == null) return null;
      final role = (user?['role'] as String?) ?? '';
      return ChatMessage(
        time: DateTime.now().toIso8601String(),
        user: username,
        text: text,
        isMod: role.toLowerCase() == 'mod',
        isSub: (user?['is_subscribed'] as bool?) ?? false,
        isVip: ((user?['follower_badges'] as List?) ?? []).contains('VIP'),
        id: (message?['id'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      _wsSub?.cancel();
      await _ws?.sink.close();
    } catch (_) {}
    _ws = null;
    _wsSub = null;
    _statusController.add(StreamStatus(live: false));
  }

  @override
  Future<bool> sendMessage(String text) async {
    final token = _accessToken;
    if (token == null) return false; // Read-only without OAuth.
    final broadcaster = _broadcasterUserId;
    if (broadcaster == null) return false;
    try {
      final res = await _http.post(
        Uri.parse('https://api.kick.com/public/v1/chat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'broadcaster_user_id': broadcaster,
          'content': text,
          'type': 'user',
        }),
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Resolve the broadcaster's numeric user id via the official API
  /// (needed as a param for chat send).
  Future<void> _resolveBroadcasterId(String slug) async {
    try {
      final res = await _http.get(
        Uri.parse('https://api.kick.com/public/v1/channels?slug=$slug'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['data'] as List?) ?? const [];
      if (items.isEmpty) return;
      final item = items.first as Map<String, dynamic>;
      final id = item['broadcaster_user_id'] ?? item['id'];
      if (id is int) _broadcasterUserId = id;
      if (id is String) _broadcasterUserId = int.tryParse(id);
    } catch (_) {}
  }

  @override
  Future<List<ChatMessage>> fetchRecentChat({int count = 30}) async =>
      const []; // Kick has no chat history API.

  @override
  Future<StreamStatus> fetchStatus() async {
    final slug = _slug;
    if (slug == null) return const StreamStatus();
    try {
      final res = await _http.get(
        Uri.parse('https://kick.com/api/v2/channels/$slug'),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const StreamStatus();
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final livestream = data['livestream'] as Map<String, dynamic>?;
      if (livestream == null) return const StreamStatus(live: false);
      final status = StreamStatus(
        live: true,
        viewers: (livestream['viewer_count'] as num?)?.toInt() ?? 0,
        title: (livestream['session_title'] as String?) ?? '',
        game: ((livestream['categories'] as List?) ?? [])
                .cast<Map<String, dynamic>>()
                .map((c) => c['name'])
                .firstWhere((_) => true, orElse: () => '')
                .toString(),
      );
      _statusController.add(status);
      return status;
    } catch (_) {
      return const StreamStatus();
    }
  }

  // ── Moderation: not available on Kick's public surfaces ──

  @override
  Future<bool> timeoutUser(String user, {int duration = 300}) async =>
      throw UnsupportedError('Kick moderation is not available');

  @override
  Future<bool> banUser(String user) async =>
      throw UnsupportedError('Kick moderation is not available');

  @override
  Future<bool> unbanUser(String user) async =>
      throw UnsupportedError('Kick moderation is not available');

  @override
  Future<bool> clearChat() async =>
      throw UnsupportedError('Kick moderation is not available');

  @override
  Future<bool> setChatMode(String mode, bool enabled) async =>
      throw UnsupportedError('Kick moderation is not available');
}
