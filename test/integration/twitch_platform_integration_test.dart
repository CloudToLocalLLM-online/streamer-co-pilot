import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/models/chat_message.dart';
import 'package:streamer_co_pilot/platforms/stream_platform.dart';
import 'package:streamer_co_pilot/platforms/twitch_helix_client.dart';
import 'package:streamer_co_pilot/platforms/twitch_irc_client.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';

class MockHelixClient extends Mock implements TwitchHelixClient {}

class MockIrcClient extends Mock implements TwitchIrcClient {}

void main() {
  late MockHelixClient mockHelix;
  late MockIrcClient mockIrc;
  late TwitchPlatform platform;

  setUp(() {
    mockHelix = MockHelixClient();
    mockIrc = MockIrcClient();
    SharedPreferences.setMockInitialValues({
      'twitch_access_token': 'test-token',
      'twitch_client_id': 'test-client-id',
      'twitch_client_secret': 'test-client-secret',
    });

    // Stub IRC connect to succeed
    when(() => mockIrc.connect()).thenAnswer((_) async => true);
    when(() => mockIrc.messages).thenAnswer((_) => const Stream.empty());
    when(() => mockIrc.disconnect()).thenReturn(null);
    when(() => mockIrc.sendMessage(any())).thenAnswer((_) async => true);

    // Stub Helix
    when(() => mockHelix.resolveUserId(any())).thenAnswer((_) async => 'broadcaster123');
    when(() => mockHelix.fetchStreamStatus(any())).thenAnswer(
      (_) async => const TwitchStreamStatus(live: false),
    );
    when(() => mockHelix.dispose()).thenReturn(null);

    platform = TwitchPlatform(
      helixClient: mockHelix,
      ircClient: mockIrc,
    );
  });

  tearDown(() {
    platform.dispose();
  });

  group('TwitchPlatform integration', () {
    test('connect() fails gracefully when no tokens saved', () async {
      SharedPreferences.setMockInitialValues({});
      final p = TwitchPlatform(helixClient: mockHelix, ircClient: mockIrc);

      final result = await p.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );

      expect(result, false);
      expect(p.connected, false);
      p.dispose();
    });

    test('connect() succeeds with valid tokens (mock)', () async {
      final result = await platform.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );

      expect(result, true);
      expect(platform.connected, true);
    });

    test('disconnect() cleans up IRC and polling', () async {
      await platform.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );
      expect(platform.connected, true);

      await platform.disconnect();

      expect(platform.connected, false);
      verify(() => mockIrc.disconnect()).called(1);
    });

    test('chat stream receives messages from IRC', () async {
      // Create a stream controller for IRC messages
      final ircController = StreamController<ChatMessage>.broadcast();
      when(() => mockIrc.messages).thenAnswer((_) => ircController.stream);

      // Recreate platform with the new mock setup
      final p = TwitchPlatform(helixClient: mockHelix, ircClient: mockIrc);

      // Collect chat messages from the platform
      final chatMessages = <ChatMessage>[];
      final sub = p.chatStream.listen((msg) => chatMessages.add(msg));

      // Connect the platform (this wires IRC messages to chatStream)
      await p.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );

      // Simulate IRC receiving a PRIVMSG
      final testMessage = ChatMessage(
        time: '12:34',
        user: 'testuser',
        text: 'Hello from chat!',
        isMod: true,
        isSub: false,
        isVip: false,
        isBroadcaster: false,
      );
      ircController.add(testMessage);

      // Allow the event to propagate
      await Future.delayed(const Duration(milliseconds: 50));

      expect(chatMessages.length, 1);
      expect(chatMessages[0].user, 'testuser');
      expect(chatMessages[0].text, 'Hello from chat!');
      expect(chatMessages[0].isMod, true);

      await sub.cancel();
      await ircController.close();
      p.dispose();
    });

    test('status stream receives updates from Helix poller', () async {
      // Stub Helix to return a live stream
      when(() => mockHelix.fetchStreamStatus(any())).thenAnswer(
        (_) async => const TwitchStreamStatus(
          live: true,
          viewers: 42,
          game: 'Just Chatting',
          title: 'My Stream',
          uptimeSec: 3600,
        ),
      );

      // Collect status updates
      final statusUpdates = <StreamStatus>[];
      final sub = platform.statusStream.listen((s) => statusUpdates.add(s));

      // Connect triggers an immediate status fetch
      await platform.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );

      // Allow the async fetch to complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(statusUpdates.length, greaterThanOrEqualTo(1));
      final lastStatus = statusUpdates.last;
      expect(lastStatus.live, true);
      expect(lastStatus.viewers, 42);
      expect(lastStatus.game, 'Just Chatting');
      expect(lastStatus.title, 'My Stream');

      await sub.cancel();
    });

    test('sendMessage() delegates to IRC', () async {
      when(() => mockIrc.sendMessage(any())).thenAnswer((_) async => true);

      await platform.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );

      final result = await platform.sendMessage('test message');

      expect(result, true);
      verify(() => mockIrc.sendMessage('test message')).called(1);
    });
  });
}
