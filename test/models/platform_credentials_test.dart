import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/platforms/stream_platform.dart';

void main() {
  group('PlatformCredentials', () {
    test('default constructor sets all fields to null', () {
      const creds = PlatformCredentials();

      expect(creds.clientId, isNull);
      expect(creds.clientSecret, isNull);
      expect(creds.accessToken, isNull);
      expect(creds.channelName, isNull);
      expect(creds.botId, isNull);
    });

    test('named constructor sets fields correctly', () {
      const creds = PlatformCredentials(
        clientId: 'abc123',
        clientSecret: 'secret456',
        accessToken: 'token789',
        channelName: 'mychannel',
        botId: 'bot999',
      );

      expect(creds.clientId, 'abc123');
      expect(creds.clientSecret, 'secret456');
      expect(creds.accessToken, 'token789');
      expect(creds.channelName, 'mychannel');
      expect(creds.botId, 'bot999');
    });

    test('partial fields use null defaults', () {
      const creds = PlatformCredentials(channelName: 'testchan');

      expect(creds.channelName, 'testchan');
      expect(creds.clientId, isNull);
      expect(creds.clientSecret, isNull);
      expect(creds.accessToken, isNull);
      expect(creds.botId, isNull);
    });
  });
}
