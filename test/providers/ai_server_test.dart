import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/providers/ai_server.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';

void main() {
  group('AiServer', () {
    test('buildSnapshot returns correct structure', () {
      final ai = AiServer();
      final snapshot = ai.buildSnapshot();

      expect(snapshot.obs.connected, false);
      expect(snapshot.platformConnected, false);
      expect(snapshot.chatMessageCount, 0);
      expect(snapshot.recentChatPreview, isEmpty);

      ai.dispose();
    });

    test('executeCommand with unknown command returns error', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('nonexistent', {});
      expect(result.success, false);
      expect(result.message, contains('Unknown command'));
      ai.dispose();
    });

    test('executeCommand with missing params returns error', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('switch_scene', {});
      expect(result.success, false);
      expect(result.message, 'Missing scene');
      ai.dispose();
    });

    test('executeCommand switch_scene returns error when OBS not connected', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('switch_scene', {'scene': 'Test'});
      expect(result.success, false);
      expect(result.message, 'OBS not connected');
      ai.dispose();
    });

    test('executeCommand toggle_source returns error when OBS not connected', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('toggle_source', {'source': 'Webcam'});
      expect(result.success, false);
      expect(result.message, 'OBS not connected');
      ai.dispose();
    });

    test('executeCommand set_source returns error when missing params', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('set_source', {'source': 'Webcam'});
      expect(result.success, false);
      expect(result.message, 'Missing source or enabled');
      ai.dispose();
    });

    test('executeCommand toggle_stream returns error when OBS not connected', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('toggle_stream', {});
      expect(result.success, false);
      expect(result.message, 'OBS not connected');
      ai.dispose();
    });

    test('executeCommand toggle_recording returns error when OBS not connected', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('toggle_recording', {});
      expect(result.success, false);
      expect(result.message, 'OBS not connected');
      ai.dispose();
    });

    test('executeCommand send_message returns error when no platform', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('send_message', {'message': 'Hello'});
      expect(result.success, false);
      ai.dispose();
    });

    test('executeCommand timeout returns error when missing user', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('timeout', {});
      expect(result.success, false);
      expect(result.message, 'Missing user');
      ai.dispose();
    });

    test('executeCommand ban returns error when missing user', () async {
      final ai = AiServer();
      final result = await ai.executeCommand('ban', {});
      expect(result.success, false);
      expect(result.message, 'Missing user');
      ai.dispose();
    });

    test('AiStateSnapshot toJson produces correct map', () {
      const obsState = ObsState(
        connected: true,
        currentScene: 'Game',
        scenes: ['Game', 'BRB'],
        streaming: true,
      );
      final snapshot = AiStateSnapshot(
        obs: obsState,
        platformConnected: true,
        chatMessageCount: 5,
        recentChatPreview: ['user1: hi', 'user2: hello'],
      );

      final json = snapshot.toJson();
      expect(json['obs']['connected'], true);
      expect(json['obs']['current_scene'], 'Game');
      expect(json['obs']['streaming'], true);
      expect(json['platform']['connected'], true);
      expect(json['chat']['total_messages'], 5);
      expect(json['chat']['recent'], hasLength(2));
    });

    test('AiCommandResult toJson produces correct map', () {
      const result = AiCommandResult(success: true, message: 'Done');
      final json = result.toJson();
      expect(json['success'], true);
      expect(json['message'], 'Done');
    });

    test('AiCommandResult with null message', () {
      const result = AiCommandResult(success: false);
      final json = result.toJson();
      expect(json['success'], false);
      expect(json['message'], isNull);
    });
  });
}
