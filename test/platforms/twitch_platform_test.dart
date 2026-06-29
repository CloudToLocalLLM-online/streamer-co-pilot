import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/platforms/stream_platform.dart';
import 'package:streamer_co_pilot/platforms/twitch_helix_client.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';

class MockHelixClient extends Mock implements TwitchHelixClient {}

void main() {
  late MockHelixClient mockHelix;
  late TwitchPlatform platform;

  setUp(() {
    mockHelix = MockHelixClient();
    SharedPreferences.setMockInitialValues({});
    platform = TwitchPlatform(helixClient: mockHelix);
  });

  group('TwitchPlatform', () {
    test('connect() fails gracefully when no tokens saved', () async {
      // SharedPreferences is empty, so loadTokens() returns false
      final result = await platform.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );

      expect(result, false);
      expect(platform.connected, false);
    });

    test('disconnect() cleans up', () async {
      // Even without being connected, disconnect should not throw
      await platform.disconnect();
      expect(platform.connected, false);
    });

    test('sendMessage() delegates to IRC', () async {
      // When not connected, _irc is null, so sendMessage returns false
      final result = await platform.sendMessage('test message');
      expect(result, false);
    });
  });
}
