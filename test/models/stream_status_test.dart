import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/platforms/stream_platform.dart';

void main() {
  group('StreamStatus', () {
    test('default constructor sets all fields to false/0/empty', () {
      const status = StreamStatus();

      expect(status.live, false);
      expect(status.viewers, 0);
      expect(status.game, '');
      expect(status.title, '');
      expect(status.uptimeSec, 0);
    });

    test('named constructor sets fields correctly', () {
      const status = StreamStatus(
        live: true,
        viewers: 42,
        game: 'Just Chatting',
        title: 'Chill stream',
        uptimeSec: 3600,
      );

      expect(status.live, true);
      expect(status.viewers, 42);
      expect(status.game, 'Just Chatting');
      expect(status.title, 'Chill stream');
      expect(status.uptimeSec, 3600);
    });

    test('partial fields use defaults', () {
      const status = StreamStatus(live: true);

      expect(status.live, true);
      expect(status.viewers, 0);
      expect(status.game, '');
      expect(status.title, '');
      expect(status.uptimeSec, 0);
    });
  });
}
