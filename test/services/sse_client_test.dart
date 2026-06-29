import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/services/sse_client.dart';

void main() {
  group('SseClient', () {
    test('constructor sets url', () {
      final client = SseClient('http://localhost:8510');
      // No public url getter, but we can verify it doesn't crash
      expect(client, isNotNull);
      client.disconnect();
    });

    test('disconnect closes cleanly when not connected', () {
      final client = SseClient('http://localhost:8510');
      // Should not throw when called on unconnected client
      expect(() => client.disconnect(), returnsNormally);
    });

    test('disconnect is idempotent', () {
      final client = SseClient('http://localhost:8510');
      client.disconnect();
      client.disconnect();
      client.disconnect();
      expect(() => client.disconnect(), returnsNormally);
    });
  });
}
