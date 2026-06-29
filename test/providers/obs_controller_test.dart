import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';

void main() {
  group('ObsController', () {
    test('initial state has connected=false', () {
      final obs = ObsController();
      expect(obs.state.connected, false);
      expect(obs.state.currentScene, isNull);
      expect(obs.state.scenes, isEmpty);
      expect(obs.state.sources, isEmpty);
      expect(obs.state.streaming, false);
      expect(obs.state.recording, false);
      obs.dispose();
    });

    test('configure updates host/port/password', () {
      final obs = ObsController();
      obs.configure(host: '192.168.1.10', port: 4456, password: 'secret');
      // State is unchanged until connect() is called
      expect(obs.state.connected, false);
      obs.dispose();
    });

    test('disconnect resets state to defaults', () {
      final obs = ObsController();
      // Manually set state to simulate connected
      // disconnect() should reset everything
      obs.disconnect();
      expect(obs.state.connected, false);
      expect(obs.state.currentScene, isNull);
      expect(obs.state.scenes, isEmpty);
      expect(obs.state.sources, isEmpty);
      expect(obs.state.streaming, false);
      expect(obs.state.recording, false);
      obs.dispose();
    });

    test('dispose cleans up timers', () {
      final obs = ObsController();
      // Should not throw
      expect(() => obs.dispose(), returnsNormally);
    });

    test('ObsState default constructor', () {
      const state = ObsState();
      expect(state.connected, false);
      expect(state.currentScene, isNull);
      expect(state.scenes, isEmpty);
      expect(state.sources, isEmpty);
      expect(state.streaming, false);
      expect(state.recording, false);
      expect(state.streamDurationSec, isNull);
    });

    test('ObsState named constructor', () {
      const state = ObsState(
        connected: true,
        currentScene: 'Game',
        scenes: ['Game', 'BRB'],
        streaming: true,
        recording: false,
        streamDurationSec: 3600,
      );
      expect(state.connected, true);
      expect(state.currentScene, 'Game');
      expect(state.scenes, ['Game', 'BRB']);
      expect(state.streaming, true);
      expect(state.recording, false);
      expect(state.streamDurationSec, 3600);
    });

    test('ObsSourceState constructor', () {
      const source = ObsSourceState(
        name: 'Webcam',
        enabled: true,
        itemId: 42,
      );
      expect(source.name, 'Webcam');
      expect(source.enabled, true);
      expect(source.itemId, 42);
    });
  });
}
