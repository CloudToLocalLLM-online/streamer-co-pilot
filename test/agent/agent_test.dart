import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:streamer_co_pilot/agent/agent_client.dart';
import 'package:streamer_co_pilot/agent/decision_loop.dart';

// Mock HTTP client
class MockHttpClient extends Mock implements http.Client {}

class MockHttpResponse extends Mock implements http.Response {}

class MockByteStream extends Mock implements Stream<List<int>> {}

void main() {
  late MockHttpClient mockClient;
  late AgentClient client;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    mockClient = MockHttpClient();
    client = AgentClient(baseUrl: 'http://localhost:8511', httpClient: mockClient);
  });

  tearDown(() async {
    await client.close();
  });

  group('AgentState', () {
    test('fromJson parses full state correctly', () {
      final json = {
        'obs': {
          'connected': true,
          'current_scene': 'Gaming',
          'scenes': ['Starting', 'Gaming', 'BRB'],
          'streaming': true,
          'recording': false,
          'stream_duration_sec': 3600,
          'sources': [
            {
              'name': 'Game Capture',
              'enabled': true,
              'volume_mul': 1.0,
              'volume_db': 0.0,
              'muted': false,
              'audio_balance': 0.0,
              'audio_sync_offset': 0,
              'audio_monitor_type': 0,
              'audio_tracks': [1, 2],
            }
          ],
          'audio_channels': [
            {
              'type': 'microphone',
              'name': 'Mic',
              'source_name': 'Microphone',
              'source_found': true,
              'volume_mul': 0.8,
              'volume_db': -2.0,
              'muted': false,
              'audio_balance': 0.0,
              'audio_sync_offset': 0,
              'audio_monitor_type': 2,
              'audio_tracks': [1],
            }
          ],
        },
        'platform': {'connected': true},
        'chat': {
          'total_messages': 42,
          'recent': ['user1: hello', 'user2: !game'],
        },
      };

      final state = AgentState.fromJson(json);

      expect(state.obsConnected, true);
      expect(state.currentScene, 'Gaming');
      expect(state.scenes, ['Starting', 'Gaming', 'BRB']);
      expect(state.streaming, true);
      expect(state.recording, false);
      expect(state.streamDurationSec, 3600);
      expect(state.sources.length, 1);
      expect(state.sources.first.name, 'Game Capture');
      expect(state.audioChannels.length, 1);
      expect(state.audioChannels.first.type, 'microphone');
      expect(state.platformConnected, true);
      expect(state.chatMessageCount, 42);
      expect(state.recentChatPreview, ['user1: hello', 'user2: !game']);
    });

    test('fromJson handles missing/partial data gracefully', () {
      final json = <String, dynamic>{};

      final state = AgentState.fromJson(json);

      expect(state.obsConnected, false);
      expect(state.currentScene, null);
      expect(state.scenes, isEmpty);
      expect(state.streaming, false);
      expect(state.recording, false);
      expect(state.streamDurationSec, 0);
      expect(state.sources, isEmpty);
      expect(state.audioChannels, isEmpty);
      expect(state.platformConnected, false);
      expect(state.chatMessageCount, 0);
      expect(state.recentChatPreview, isEmpty);
    });
  });

  group('ObsSource', () {
    test('fromJson parses correctly', () {
      final json = {
        'name': 'Test Source',
        'enabled': true,
        'volume_mul': 0.5,
        'volume_db': -6.0,
        'muted': true,
        'audio_balance': 0.3,
        'audio_sync_offset': 100,
        'audio_monitor_type': 1,
        'audio_tracks': [1],
      };

      final source = ObsSource.fromJson(json);

      expect(source.name, 'Test Source');
      expect(source.enabled, true);
      expect(source.volumeMul, 0.5);
      expect(source.volumeDb, -6.0);
      expect(source.muted, true);
      expect(source.audioBalance, 0.3);
      expect(source.audioSyncOffset, 100);
      expect(source.audioMonitorType, 1);
      expect(source.audioTracks, [1]);
    });
  });

  group('AudioChannel', () {
    test('fromJson parses correctly', () {
      final json = {
        'type': 'music_desktop',
        'name': 'Desktop Audio',
        'source_name': 'Desktop',
        'source_found': true,
        'volume_mul': 1.0,
        'volume_db': 0.0,
        'muted': false,
        'audio_balance': 0.0,
        'audio_sync_offset': 0,
        'audio_monitor_type': 0,
        'audio_tracks': [1, 2],
      };

      final channel = AudioChannel.fromJson(json);

      expect(channel.type, 'music_desktop');
      expect(channel.name, 'Desktop Audio');
      expect(channel.sourceName, 'Desktop');
      expect(channel.sourceFound, true);
      expect(channel.volumeMul, 1.0);
      expect(channel.muted, false);
    });
  });

  group('CommandResult', () {
    test('fromJson parses success', () {
      final json = {'success': true, 'message': 'OK'};
      final result = CommandResult.fromJson(json);
      expect(result.success, true);
      expect(result.message, 'OK');
    });

    test('fromJson parses failure', () {
      final json = {'success': false, 'message': 'Failed'};
      final result = CommandResult.fromJson(json);
      expect(result.success, false);
      expect(result.message, 'Failed');
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};
      final result = CommandResult.fromJson(json);
      expect(result.success, false);
      expect(result.message, null);
    });
  });

  group('SseEvent', () {
    test('fromRaw parses event:data format', () {
      const raw = 'event: obs_state\ndata: {"connected": true}\n\n';
      final event = SseEvent.fromRaw(raw);

      expect(event.eventType, 'obs_state');
      expect(event.data['connected'], true);
    });

    test('fromRaw handles data without event type', () {
      const raw = 'data: {"key": "value"}\n\n';
      final event = SseEvent.fromRaw(raw);

      expect(event.eventType, 'unknown');
      expect(event.data['key'], 'value');
    });

    test('fromRaw skips comment lines', () {
      const raw = ': heartbeat\n\nevent: chat_message\ndata: {"user": "test"}\n\n';
      final event = SseEvent.fromRaw(raw);

      expect(event.eventType, 'chat_message');
      expect(event.data['user'], 'test');
    });

    test('fromRaw handles malformed JSON gracefully', () {
      const raw = 'event: test\ndata: not json\n\n';
      final event = SseEvent.fromRaw(raw);

      expect(event.eventType, 'test');
      expect(event.data['raw'], 'not json');
    });
  });

  group('AgentClient', () {
    late MockHttpResponse mockResponse;

    setUp(() {
      mockResponse = MockHttpResponse();
    });

    test('healthCheck returns true on 200 OK', () async {
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.body).thenReturn('{"status": "ok"}');
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final result = await client.healthCheck();
      expect(result, true);
    });

    test('healthCheck returns false on non-200', () async {
      when(() => mockResponse.statusCode).thenReturn(500);
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final result = await client.healthCheck();
      expect(result, false);
    });

    test('healthCheck returns false on exception', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Connection refused'));

      final result = await client.healthCheck();
      expect(result, false);
    });

    test('getState returns parsed state on 200', () async {
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.body).thenReturn(jsonEncode({
        'obs': {'connected': true, 'streaming': false},
        'platform': {'connected': false},
        'chat': {'total_messages': 0, 'recent': []},
      }));
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final state = await client.getState();
      expect(state.obsConnected, true);
      expect(state.streaming, false);
      expect(state.platformConnected, false);
    });

    test('getState throws on non-200', () async {
      when(() => mockResponse.statusCode).thenReturn(404);
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      expect(() => client.getState(), throwsException);
    });

    test('sendCommand posts JSON and returns result', () async {
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.body).thenReturn('{"success": true, "message": "Switched"}');
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => mockResponse);

      final result = await client.sendCommand('switch_scene', {'scene': 'Gaming'});
      expect(result.success, true);
      expect(result.message, 'Switched');

      verify(() => mockClient.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': 'switch_scene', 'params': {'scene': 'Gaming'}}),
      )).called(1);
    });

    test('sendCommand throws on non-200', () async {
      when(() => mockResponse.statusCode).thenReturn(400);
      when(() => mockResponse.body).thenReturn('Bad Request');
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => mockResponse);

      expect(() => client.sendCommand('invalid', {}), throwsException);
    });
  });

  group('DecisionLoop', () {
      late MockHttpClient mockClient;
      late AgentClient testClient;
      late DecisionLoopConfig config;
      late List<String> logMessages;

      // Helper to create a mock response
      MockHttpResponse createMockResponse({int statusCode = 200, String body = ''}) {
        final mock = MockHttpResponse();
        when(() => mock.statusCode).thenReturn(statusCode);
        when(() => mock.body).thenReturn(body);
        return mock;
      }

      setUp(() {
        mockClient = MockHttpClient();
        testClient = AgentClient(baseUrl: 'http://localhost:8511', httpClient: mockClient);
        logMessages = [];
        config = DecisionLoopConfig(
          pollInterval: const Duration(milliseconds: 10),
          rules: [],
          onLog: (msg) => logMessages.add(msg),
        );
      });

      tearDown(() async {
        await testClient.close();
      });

      test('starts and stops cleanly', () async {
        final loop = DecisionLoop(client: testClient, config: config);
        expect(loop.isRunning, false);
        expect(loop.iteration, 0);

        await loop.stop();
        expect(loop.isRunning, false);
      });

      test('runOnce returns empty list when no rules', () async {
        // Mock getState for runOnce (health check not called by runOnce)
        final stateResponse = createMockResponse(body: jsonEncode({
          'obs': {'connected': false, 'streaming': false},
          'platform': {'connected': false},
          'chat': {'total_messages': 0, 'recent': []},
        }));

        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => stateResponse);

        final loop = DecisionLoop(client: testClient, config: config);
        final results = await loop.runOnce();

        expect(results, isEmpty);
        expect(loop.iteration, 1);
      });

      test('runOnce executes rule when condition met', () async {
        final stateResponse = createMockResponse(body: jsonEncode({
          'obs': {
            'connected': true,
            'current_scene': 'Starting',
            'scenes': ['Starting', 'Gaming'],
            'streaming': false,
            'recording': false,
            'stream_duration_sec': 0,
            'sources': [],
            'audio_channels': [],
          },
          'platform': {'connected': true},
          'chat': {'total_messages': 0, 'recent': []},
        }));

        final commandResponse = createMockResponse(body: '{"success": true, "message": "Stream started"}');

        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => stateResponse);
        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => commandResponse);

        final ruleConfig = DecisionLoopConfig(
          pollInterval: const Duration(milliseconds: 10),
          rules: [autoStartStreamRule()],
          onLog: (msg) => logMessages.add(msg),
        );

        final loop = DecisionLoop(client: testClient, config: ruleConfig);
        final results = await loop.runOnce();

        expect(results.length, 1);
        expect(results.first.ruleName, 'auto_start_stream');
        expect(results.first.conditionMet, true);
        expect(results.first.commandResult?.success, true);
        expect(loop.iteration, 1);
      });

      test('runOnce does not execute rule when condition not met', () async {
        final stateResponse = createMockResponse(body: jsonEncode({
          'obs': {
            'connected': false,
            'current_scene': null,
            'scenes': [],
            'streaming': false,
            'recording': false,
            'stream_duration_sec': 0,
            'sources': [],
            'audio_channels': [],
          },
          'platform': {'connected': true},
          'chat': {'total_messages': 0, 'recent': []},
        }));

        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => stateResponse);

        final ruleConfig = DecisionLoopConfig(
          pollInterval: const Duration(milliseconds: 10),
          rules: [autoStartStreamRule()],
          onLog: (msg) => logMessages.add(msg),
        );

        final loop = DecisionLoop(client: testClient, config: ruleConfig);
        final results = await loop.runOnce();

        expect(results, isEmpty);
        expect(loop.iteration, 1);
      });

      test('runOnce handles command failure gracefully', () async {
        final stateResponse = createMockResponse(body: jsonEncode({
          'obs': {
            'connected': true,
            'current_scene': 'Starting',
            'scenes': ['Starting', 'Gaming'],
            'streaming': false,
            'recording': false,
            'stream_duration_sec': 0,
            'sources': [],
            'audio_channels': [],
          },
          'platform': {'connected': true},
          'chat': {'total_messages': 0, 'recent': []},
        }));

        final commandResponse = createMockResponse(statusCode: 500, body: 'Internal Server Error');

        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => stateResponse);
        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => commandResponse);

        final ruleConfig = DecisionLoopConfig(
          pollInterval: const Duration(milliseconds: 10),
          rules: [autoStartStreamRule()],
          onLog: (msg) => logMessages.add(msg),
        );

        final loop = DecisionLoop(client: testClient, config: ruleConfig);
        final results = await loop.runOnce();

        expect(results.length, 1);
        expect(results.first.ruleName, 'auto_start_stream');
        expect(results.first.conditionMet, true);
        expect(results.first.commandResult, isNull);
        expect(results.first.error, isNotNull);
        expect(results.first.success, false);
      });

      test('shouldContinue stops loop when false', () async {
            final stateResponse = createMockResponse(body: jsonEncode({
              'obs': {'connected': false, 'streaming': false},
              'platform': {'connected': false},
              'chat': {'total_messages': 0, 'recent': []},
            }));

            when(() => mockClient.get(any(), headers: any(named: 'headers')))
                .thenAnswer((_) async => stateResponse);

            int continueCalls = 0;
            final ruleConfig = DecisionLoopConfig(
              pollInterval: const Duration(milliseconds: 10),
              rules: [],
              onLog: (msg) => logMessages.add(msg),
              shouldContinue: (state) {
                continueCalls++;
                return continueCalls < 2; // Stop after 2 iterations
              },
            );

            final loop = DecisionLoop(client: testClient, config: ruleConfig);

            // Run first iteration - shouldContinue returns true, loop continues
            final results1 = await loop.runOnce();
            expect(results1, isEmpty);
            expect(continueCalls, 1);

            // Run second iteration - shouldContinue returns false, loop stops early
            final results2 = await loop.runOnce();
            expect(results2, isEmpty);
            expect(continueCalls, 2);
            // Note: runOnce() doesn't set _running = true (only start() does),
            // so isRunning remains false. The shouldContinue callback still works.
          });
    });

  group('Built-in DecisionRules', () {
    test('autoStartStreamRule condition matches when live + OBS ready + not streaming', () {
      final rule = autoStartStreamRule();
      final state = AgentState(
        obsConnected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming'],
        streaming: false,
        recording: false,
        streamDurationSec: 0,
        sources: [],
        audioChannels: [],
        platformConnected: true,
        chatMessageCount: 0,
        recentChatPreview: [],
      );

      expect(rule.condition(state), true);
    });

    test('autoStartStreamRule condition fails when already streaming', () {
      final rule = autoStartStreamRule();
      final state = AgentState(
        obsConnected: true,
        currentScene: 'Gaming',
        scenes: ['Starting', 'Gaming'],
        streaming: true,
        recording: false,
        streamDurationSec: 100,
        sources: [],
        audioChannels: [],
        platformConnected: true,
        chatMessageCount: 0,
        recentChatPreview: [],
      );

      expect(rule.condition(state), false);
    });

    test('autoStartStreamRule condition fails when OBS not connected', () {
      final rule = autoStartStreamRule();
      final state = AgentState(
        obsConnected: false,
        currentScene: null,
        scenes: [],
        streaming: false,
        recording: false,
        streamDurationSec: 0,
        sources: [],
        audioChannels: [],
        platformConnected: true,
        chatMessageCount: 0,
        recentChatPreview: [],
      );

      expect(rule.condition(state), false);
    });

    test('switchToStartingSceneRule triggers when streaming but not on Starting scene', () {
      final rule = switchToStartingSceneRule();
      final state = AgentState(
        obsConnected: true,
        currentScene: 'Gaming',
        scenes: ['Starting', 'Gaming', 'BRB'],
        streaming: true,
        recording: false,
        streamDurationSec: 100,
        sources: [],
        audioChannels: [],
        platformConnected: true,
        chatMessageCount: 0,
        recentChatPreview: [],
      );

      expect(rule.condition(state), true);
    });

    test('switchToStartingSceneRule does not trigger when already on Starting', () {
      final rule = switchToStartingSceneRule();
      final state = AgentState(
        obsConnected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming'],
        streaming: true,
        recording: false,
        streamDurationSec: 100,
        sources: [],
        audioChannels: [],
        platformConnected: true,
        chatMessageCount: 0,
        recentChatPreview: [],
      );

      expect(rule.condition(state), false);
    });

    test('chatGameCommandRule triggers on !game in recent chat', () {
      final rule = chatGameCommandRule();
      final state = AgentState(
        obsConnected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming'],
        streaming: true,
        recording: false,
        streamDurationSec: 100,
        sources: [],
        audioChannels: [],
        platformConnected: true,
        chatMessageCount: 5,
        recentChatPreview: ['user1: hello', 'user2: !game'],
      );

      expect(rule.condition(state), true);
    });

    test('chatGameCommandRule does not trigger without !game', () {
      final rule = chatGameCommandRule();
      final state = AgentState(
        obsConnected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming'],
        streaming: true,
        recording: false,
        streamDurationSec: 100,
        sources: [],
        audioChannels: [],
        platformConnected: true,
        chatMessageCount: 5,
        recentChatPreview: ['user1: hello', 'user2: hi there'],
      );

      expect(rule.condition(state), false);
    });

    test('chatMuteCommandRule triggers on !mute in recent chat', () {
      final rule = chatMuteCommandRule();
      final state = AgentState(
        obsConnected: true,
        currentScene: 'Gaming',
        scenes: ['Starting', 'Gaming'],
        streaming: true,
        recording: false,
        streamDurationSec: 100,
        sources: [],
        audioChannels: [],
        platformConnected: true,
        chatMessageCount: 5,
        recentChatPreview: ['user1: !mute'],
      );

      expect(rule.condition(state), true);
    });

    test('defaultRules returns non-empty list', () {
      final rules = defaultRules();
      expect(rules, isNotEmpty);
      expect(rules.length, 2); // autoStartStream + switchToStartingScene
    });
  });
}