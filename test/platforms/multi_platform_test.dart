import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamer_co_pilot/models/chat_message.dart';
import 'package:streamer_co_pilot/platforms/kick_platform.dart';
import 'package:streamer_co_pilot/platforms/multi_platform_manager.dart';
import 'package:streamer_co_pilot/platforms/stream_platform.dart';
import 'package:streamer_co_pilot/platforms/youtube_platform.dart';

/// Minimal fake platform for manager tests.
class FakePlatform extends StreamPlatform {
  final String name_;
  FakePlatform(this.name_);
  @override
  String get platformName => name_;
  @override
  bool get connected => false;
  @override
  Stream<ChatMessage> get chatStream => const Stream.empty();
  @override
  Stream<StreamStatus> get statusStream => const Stream.empty();
  @override
  Future<bool> connect(PlatformCredentials creds) async => true;
  @override
  Future<void> disconnect() async {}
  @override
  Future<bool> sendMessage(String text) async => true;
  @override
  Future<List<ChatMessage>> fetchRecentChat({int count = 30}) async => [];
  @override
  Future<StreamStatus> fetchStatus() async => const StreamStatus(live: true);
  @override
  Future<bool> timeoutUser(String user, {int duration = 300}) async => true;
  @override
  Future<bool> banUser(String user) async => true;
  @override
  Future<bool> unbanUser(String user) async => true;
  @override
  Future<bool> clearChat() async => true;
  @override
  Future<bool> setChatMode(String mode, bool enabled) async => true;
}

void main() {
  group('MultiPlatformManager', () {
    test('add registers platforms and reports merged platformName', () {
      final manager = MultiPlatformManager();
      manager.add(FakePlatform('Twitch'));
      manager.add(FakePlatform('Kick'));
      expect(manager.platformName, 'Twitch+Kick');
      expect(manager.platforms.length, 2);
    });

    test('add is idempotent per instance', () {
      final manager = MultiPlatformManager();
      final p = FakePlatform('Twitch');
      manager.add(p);
      manager.add(p);
      expect(manager.platforms.length, 1);
    });

    test('merged chat stream receives from all platforms', () async {
      final a = _ChattyPlatform('Twitch');
      final b = _ChattyPlatform('Kick');
      final manager = MultiPlatformManager();
      manager.add(a);
      manager.add(b);

      final received = <String>[];
      final sub = manager.chatStream.listen((m) => received.add(m.user));
      await Future.delayed(Duration.zero);

      a.emit(ChatMessage(time: '1', user: 'alice', text: 'hi'));
      b.emit(ChatMessage(time: '2', user: 'bob', text: 'yo'));
      await Future.delayed(Duration.zero);
      expect(received, containsAll(['alice', 'bob']));
      await sub.cancel();
    });

    test('sendMessage broadcasts to connected platforms only', () async {
      final sender = _SendTrackingPlatform('Twitch');
      final manager = MultiPlatformManager();
      manager.add(sender);
      sender.connected_ = true;

      expect(await manager.sendMessage('hello'), isTrue);
      expect(sender.sentMessages, ['hello']);
    });

    test('moderation skips platforms that throw UnsupportedError', () async {
      final mod = _ModSupportingPlatform('Twitch');
      final noMod = _NoModPlatform('Kick');
      final manager = MultiPlatformManager();
      manager.add(mod);
      manager.add(noMod);

      expect(await manager.banUser('spammer'), isTrue);
      expect(mod.bannedUsers, ['spammer']);
    });
  });

  group('KickPlatform parsing', () {
    test('parses ChatMessageSentEvent frames into ChatMessage', () async {
      final kick = KickPlatform(
        httpClient: MockClient((_) async =>
            http.Response(jsonEncode({'chatroom': {'id': 123}}), 200)),
      );
      // Access the private handler through a public test seam:
      // feed a frame through the same code path via fetchChatroomId + ws parse.
      final frame = jsonEncode({
        'event': r'App\Events\ChatMessageSentEvent',
        'data': jsonEncode({
          'message': {'id': 'abc', 'message': 'hello world'},
          'user': {
            'username': 'viewer1',
            'role': 'mod',
            'is_subscribed': true,
            'follower_badges': ['VIP'],
          },
        }),
        'channel': 'chatrooms.123',
      });

      // Use the exported test hook if present; otherwise invoke via reflection
      // is unavailable in Dart — call the public method used by tests.
      final result = kick.parseWsFrameForTest(frame);
      expect(result, isNotNull);
      expect(result!.user, 'viewer1');
      expect(result.text, 'hello world');
      expect(result.isMod, isTrue);
      expect(result.isSub, isTrue);
      expect(result.isVip, isTrue);
    });

    test('ignores malformed and non-chat events', () async {
      final kick = KickPlatform(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(kick.parseWsFrameForTest('not json'), isNull);
      expect(kick.parseWsFrameForTest(jsonEncode({'event': 'pusher:ping'})),
          isNull);
    });
  });

  group('YoutubePlatform', () {
    test('connect fails without access token', () async {
      final yt = YoutubePlatform();
      expect(await yt.connect(const PlatformCredentials()), isFalse);
    });

    test('sendMessage fails when not connected', () async {
      final yt = YoutubePlatform();
      expect(await yt.sendMessage('hi'), isFalse);
    });
  });
}

// ── Fakes ──

class _ChattyPlatform extends StreamPlatform {
  final _controller = StreamController<ChatMessage>.broadcast();
  _ChattyPlatform(String name) : name_ = name;
  final String name_;

  void emit(ChatMessage m) => _controller.add(m);

  @override
  String get platformName => name_;
  @override
  bool get connected => true;
  @override
  Stream<ChatMessage> get chatStream => _controller.stream;
  @override
  Stream<StreamStatus> get statusStream => const Stream.empty();
  @override
  Future<bool> connect(PlatformCredentials creds) async => true;
  @override
  Future<void> disconnect() async {}
  @override
  Future<bool> sendMessage(String text) async => true;
  @override
  Future<List<ChatMessage>> fetchRecentChat({int count = 30}) async => [];
  @override
  Future<StreamStatus> fetchStatus() async => const StreamStatus();
  @override
  Future<bool> timeoutUser(String user, {int duration = 300}) async =>
      throw UnsupportedError('no moderation here');
  @override
  Future<bool> banUser(String user) async =>
      throw UnsupportedError('no moderation here');
  @override
  Future<bool> unbanUser(String user) async =>
      throw UnsupportedError('no moderation here');
  @override
  Future<bool> clearChat() async =>
      throw UnsupportedError('no moderation here');
  @override
  Future<bool> setChatMode(String mode, bool enabled) async =>
      throw UnsupportedError('no moderation here');
}

class _SendTrackingPlatform extends _ChattyPlatform {
  _SendTrackingPlatform(super.name);
  final sentMessages = <String>[];
  bool connected_ = false;

  @override
  bool get connected => connected_;
  @override
  Future<bool> sendMessage(String text) async {
    sentMessages.add(text);
    return true;
  }
}

class _ModSupportingPlatform extends _ChattyPlatform {
  _ModSupportingPlatform(super.name);
  final bannedUsers = <String>[];
  @override
  Future<bool> banUser(String user) async {
    bannedUsers.add(user);
    return true;
  }
}

class _NoModPlatform extends _ChattyPlatform {
  _NoModPlatform(super.name);
  @override
  Future<bool> banUser(String user) async =>
      throw UnsupportedError('no moderation here');
}
