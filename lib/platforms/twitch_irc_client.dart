import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';

/// Low-level Twitch IRC client.
///
/// Connects to irc.chat.twitch.tv:6697 via TLS, handles capability
/// negotiation, parses PRIVMSG, and emits chat messages as a stream.
class TwitchIrcClient {
  final String _username;
  final String _oauthToken;
  final String _channel;

  WebSocket? _socket;
  StreamController<ChatMessage>? _messageController;
  StreamSubscription? _socketSub;
  Timer? _pingTimer;
  bool _connected = false;

  bool get connected => _connected;

  /// Stream of parsed chat messages.
  late final Stream<ChatMessage> messages;

  TwitchIrcClient({
    required String username,
    required String oauthToken,
    required String channel,
  })  : _username = username,
        _oauthToken = oauthToken,
        _channel = channel {
    messages = _initMessageStream();
  }

  Stream<ChatMessage> _initMessageStream() {
    _messageController = StreamController<ChatMessage>.broadcast();
    return _messageController!.stream;
  }

  /// Connect to Twitch IRC.
  Future<bool> connect() async {
    try {
      _socket = await WebSocket.connect(
        'wss://irc-ws.chat.twitch.tv:443',
      );

      _socketSub = _socket!.listen(
        _onMessage,
        onError: (e) {
          debugPrint('[TwitchIrc] Socket error: $e');
          _connected = false;
        },
        onDone: () {
          debugPrint('[TwitchIrc] Socket closed');
          _connected = false;
        },
        cancelOnError: false,
      );

      // Authenticate
      _send('PASS oauth:$_oauthToken');
      _send('NICK $_username');
      _send('CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands');
      _send('JOIN #$_channel');

      // Start ping keepalive
      _pingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        _send('PING :tmi.twitch.tv');
      });

      _connected = true;
      return true;
    } catch (e) {
      debugPrint('[TwitchIrc] Connection failed: $e');
      _connected = false;
      return false;
    }
  }

  /// Disconnect from IRC.
  void disconnect() {
    _pingTimer?.cancel();
    _socketSub?.cancel();
    _socket?.close();
    _socket = null;
    _connected = false;
  }

  /// Send a raw IRC message.
  void _send(String message) {
    if (_socket != null && _connected) {
      _socket!.add('$message\r\n');
    }
  }

  /// Send a chat message to the channel.
  Future<bool> sendMessage(String text) async {
    if (!_connected) return false;
    try {
      _send('PRIVMSG #$_channel :$text');
      return true;
    } catch (e) {
      debugPrint('[TwitchIrc] Send error: $e');
      return false;
    }
  }

  /// Handle an incoming IRC message.
  void _onMessage(dynamic data) {
    final raw = data as String;
    for (final line in raw.split('\r\n')) {
      if (line.isEmpty) continue;

      // Handle PING
      if (line.startsWith('PING')) {
        _send('PONG :tmi.twitch.tv');
        continue;
      }

      // Parse PRIVMSG with tags
      // Format: @badges=...;color=... :user!user@user.tmi.twitch.tv PRIVMSG #channel :message
      if (line.contains('PRIVMSG')) {
        final msg = _parsePrivMsg(line);
        if (msg != null && _messageController != null && !_messageController!.isClosed) {
          _messageController!.add(msg);
        }
      }
    }
  }

  /// Parse a PRIVMSG line into a ChatMessage.
  ChatMessage? _parsePrivMsg(String line) {
    try {
      // Extract tags (everything before the first ':user!')
      String? tags;
      String rest = line;
      if (line.startsWith('@')) {
        final tagEnd = line.indexOf(' ');
        tags = line.substring(1, tagEnd);
        rest = line.substring(tagEnd + 1);
      }

      // Extract username
      // Format: user!user@user.tmi.twitch.tv
      final userMatch = RegExp(r'^:(\w+)!').firstMatch(rest);
      if (userMatch == null) return null;
      final user = userMatch.group(1)!;

      // Extract message text
      final msgMatch = RegExp(r' PRIVMSG #[^ ]+ :(.+)$').firstMatch(rest);
      if (msgMatch == null) return null;
      final text = msgMatch.group(1)!;

      // Parse tags
      bool isMod = false;
      bool isSub = false;
      bool isVip = false;
      bool isBroadcaster = false;
      String? time;

      if (tags != null) {
        for (final tag in tags.split(';')) {
          final parts = tag.split('=');
          if (parts.length != 2) continue;
          final key = parts[0];
          final value = parts[1];
          switch (key) {
            case 'mod':
              isMod = value == '1';
              break;
            case 'subscriber':
              isSub = value == '1';
              break;
            case 'vip':
              isVip = value == '1';
              break;
            case 'badges':
              isBroadcaster = value.contains('broadcaster');
              break;
            case 'tmi-sent-ts':
              if (value.isNotEmpty) {
                final ts = int.tryParse(value);
                if (ts != null) {
                  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                  time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                }
              }
              break;
          }
        }
      }

      return ChatMessage(
        time: time ?? '',
        user: user,
        text: text,
        isMod: isMod,
        isSub: isSub,
        isVip: isVip,
        isBroadcaster: isBroadcaster,
      );
    } catch (e) {
      debugPrint('[TwitchIrc] Parse error: $e');
      return null;
    }
  }

  /// Clean up.
  void dispose() {
    disconnect();
    _messageController?.close();
  }
}
