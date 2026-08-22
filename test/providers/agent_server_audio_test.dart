import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/providers/agent_server.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AgentServer audio commands (no OBS connected)', () {
    test('get_source_volume fails when OBS not connected', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('get_source_volume', {'source': 'Mic'});
      expect(r.success, false);
      expect(r.message, 'OBS not connected');
      ai.dispose();
    });

    test('get_source_volume missing source', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('get_source_volume', {});
      expect(r.success, false);
      expect(r.message, 'Missing source');
      ai.dispose();
    });

    test('set_source_volume missing volume', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('set_source_volume', {'source': 'Mic'});
      expect(r.success, false);
      expect(r.message, 'Missing source or volume');
      ai.dispose();
    });

    test('set_source_mute missing muted', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('set_source_mute', {'source': 'Mic'});
      expect(r.success, false);
      expect(r.message, 'Missing source or muted');
      ai.dispose();
    });

    test('toggle_source_mute missing source', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('toggle_source_mute', {});
      expect(r.success, false);
      expect(r.message, 'Missing source');
      ai.dispose();
    });

    test('set_source_audio_balance missing balance', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('set_source_audio_balance', {'source': 'Mic'});
      expect(r.success, false);
      expect(r.message, 'Missing source or balance');
      ai.dispose();
    });

    test('set_source_audio_sync_offset missing offset_ms', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('set_source_audio_sync_offset', {'source': 'Mic'});
      expect(r.success, false);
      expect(r.message, 'Missing source or offset_ms');
      ai.dispose();
    });

    test('set_source_audio_monitor_type missing monitor_type', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('set_source_audio_monitor_type', {'source': 'Mic'});
      expect(r.success, false);
      expect(r.message, 'Missing source or monitor_type');
      ai.dispose();
    });

    test('get_audio_channel_volume missing channel', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('get_audio_channel_volume', {});
      expect(r.success, false);
      expect(r.message, 'Missing channel');
      ai.dispose();
    });

    test('set_audio_channel_volume missing volume', () async {
      final ai = AgentServer();
      final r = await ai.executeCommand('set_audio_channel_volume', {'channel': 'microphone'});
      expect(r.success, false);
      expect(r.message, 'Missing channel or volume');
      ai.dispose();
    });
  });

  group('AgentStateSnapshot with audio channels', () {
    test('snapshot includes audio_channels when present', () {
      final ai = AgentServer();
      final snapshot = ai.buildSnapshot();

      // No OBS attached → empty channels list, but key must exist
      final json = snapshot.toJson();
      expect(json['obs'].containsKey('audio_channels'), true);
      expect((json['obs']['audio_channels'] as List), isEmpty);

      ai.dispose();
    });
  });
}
