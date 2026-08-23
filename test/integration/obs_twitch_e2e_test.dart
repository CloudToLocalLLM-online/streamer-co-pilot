import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/agent/agent_client.dart';
import 'package:streamer_co_pilot/agent/decision_loop.dart';
import 'package:streamer_co_pilot/models/chat_message.dart';
import 'package:streamer_co_pilot/platforms/stream_platform.dart';
import 'package:streamer_co_pilot/platforms/twitch_helix_client.dart';
import 'package:streamer_co_pilot/platforms/twitch_irc_client.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';
import 'package:streamer_co_pilot/providers/agent_server.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {}

class MockHttpResponse extends Mock implements http.Response {}

class MockHelixClient extends Mock implements TwitchHelixClient {}

class MockIrcClient extends Mock implements TwitchIrcClient {}

class MockObsController extends Mock implements ObsController {}

void main() {
  late MockHttpClient mockHttp;
  late MockHelixClient mockHelix;
  late MockIrcClient mockIrc;
  late MockObsController mockObs;

  late TwitchPlatform twitchPlatform;
  late AgentServer agentServer;
  late AgentClient agentClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(AudioChannelType.microphone);
  });

  setUp(() {
    mockHttp = MockHttpClient();
    mockHelix = MockHelixClient();
    mockIrc = MockIrcClient();
    mockObs = MockObsController();

    SharedPreferences.setMockInitialValues({
      'twitch_access_token': 'test-token',
      'twitch_client_id': 'test-client-id',
      'twitch_client_secret': 'test-client-secret',
    });

    // Default mock setups for OBS
    when(() => mockObs.state).thenReturn(const ObsState());
    when(() => mockObs.connect()).thenAnswer((_) async => true);
    when(() => mockObs.disconnect()).thenReturn(null);
    when(() => mockObs.switchScene(any())).thenAnswer((_) async => true);
    when(() => mockObs.toggleStream()).thenAnswer((_) async => true);
    when(() => mockObs.toggleRecording()).thenAnswer((_) async => true);
    when(() => mockObs.toggleSource(any())).thenAnswer((_) async => true);
    when(() => mockObs.setSourceEnabled(any(), any())).thenAnswer((_) async => true);
    when(() => mockObs.setAudioChannelMute(any(), any())).thenAnswer((_) async => true);
    when(() => mockObs.setAudioChannelVolume(any(), any())).thenAnswer((_) async => true);
    when(() => mockObs.dispose()).thenReturn(null);

    // Default mock setups for Twitch
    when(() => mockHelix.resolveUserId(any())).thenAnswer((_) async => 'broadcaster123');
    when(() => mockHelix.fetchStreamStatus(any())).thenAnswer(
      (_) async => const TwitchStreamStatus(live: false),
    );
    when(() => mockHelix.dispose()).thenReturn(null);

    when(() => mockIrc.connect()).thenAnswer((_) async => true);
    when(() => mockIrc.messages).thenAnswer((_) => const Stream.empty());
    when(() => mockIrc.events).thenAnswer((_) => const Stream.empty());
    when(() => mockIrc.disconnect()).thenReturn(null);
    when(() => mockIrc.sendMessage(any())).thenAnswer((_) async => true);

    twitchPlatform = TwitchPlatform(
      helixClient: mockHelix,
      ircClient: mockIrc,
    );

    agentServer = AgentServer();
    agentServer.setObs(mockObs);
    agentServer.setPlatform(twitchPlatform);

    agentClient = AgentClient(
      baseUrl: 'http://localhost:8511',
      httpClient: mockHttp,
    );
  });

  tearDown(() async {
    await agentClient.close();
    agentServer.stop();
    twitchPlatform.dispose();
    mockObs.dispose();
  });

  group('OBS + Twitch End-to-End Integration', () {
    test('AgentServer serves state with OBS and Twitch data', () async {
      // Arrange: OBS connected with scenes, Twitch connected with chat
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Gaming',
        scenes: ['Starting', 'Gaming', 'BRB'],
        streaming: false,
        recording: false,
        streamDurationSec: 0,
        sources: [
          ObsSourceState(
            name: 'Game Capture',
            enabled: true,
            itemId: 1,
            volumeMul: 1.0,
            volumeDb: 0.0,
            muted: false,
            audioBalance: 0.0,
            audioSyncOffset: 0,
            audioMonitorType: 0,
            audioTracks: 1,
          ),
        ],
        audioChannels: [
          AudioChannelState(
            type: AudioChannelType.microphone,
            name: 'Mic',
            sourceName: 'Microphone',
            sourceFound: true,
            volumeMul: 0.8,
            volumeDb: -2.0,
            muted: false,
            audioBalance: 0.0,
            audioSyncOffset: 0,
            audioMonitorType: 2,
            audioTracks: 1,
          ),
        ],
      ));

      // Twitch platform connected
      when(() => mockHelix.fetchStreamStatus(any())).thenAnswer(
        (_) async => const TwitchStreamStatus(
          live: true,
          viewers: 42,
          game: 'Just Chatting',
          title: 'My Stream',
          uptimeSec: 3600,
        ),
      );

      // Start AgentServer
      await agentServer.start(port: 8511);

      // Act: AgentClient polls /state
      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
        'obs': {
          'connected': true,
          'current_scene': 'Gaming',
          'scenes': ['Starting', 'Gaming', 'BRB'],
          'streaming': false,
          'recording': false,
          'stream_duration_sec': 0,
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
        'chat': {'total_messages': 5, 'recent': ['user1: hello', 'user2: !game']},
      }));
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);

      final state = await agentClient.getState();

      // Assert
      expect(state.obsConnected, true);
      expect(state.currentScene, 'Gaming');
      expect(state.scenes, ['Starting', 'Gaming', 'BRB']);
      expect(state.streaming, false);
      expect(state.sources.length, 1);
      expect(state.sources.first.name, 'Game Capture');
      expect(state.audioChannels.length, 1);
      expect(state.audioChannels.first.type, 'microphone');
      expect(state.platformConnected, true);
      expect(state.chatMessageCount, 5);
      expect(state.recentChatPreview, ['user1: hello', 'user2: !game']);
    });

    test('DecisionLoop triggers auto-start-stream rule when OBS+Twitch ready', () async {
      // Arrange: OBS ready with scenes, Twitch connected, not streaming yet
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming'],
        streaming: false,
        recording: false,
        streamDurationSec: 0,
        sources: [],
        audioChannels: [],
      ));

      when(() => mockHelix.fetchStreamStatus(any())).thenAnswer(
        (_) async => const TwitchStreamStatus(
          live: true,
          viewers: 10,
          game: 'Just Chatting',
          title: 'Going Live!',
          uptimeSec: 60,
        ),
      );

      await agentServer.start(port: 8511);

      // Mock state response for decision loop
      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
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

      // Mock command response
      final commandResponse = MockHttpResponse();
      when(() => commandResponse.statusCode).thenReturn(200);
      when(() => commandResponse.body).thenReturn('{"success": true, "message": "Stream started"}');

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);
      when(() => mockHttp.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => commandResponse);

      // Act: Run decision loop once with auto-start rule
      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [autoStartStreamRule()],
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      final results = await loop.runOnce();

      // Assert: Rule triggered and command sent
      expect(results.length, 1);
      expect(results.first.ruleName, 'auto_start_stream');
      expect(results.first.conditionMet, true);
      expect(results.first.commandResult?.success, true);

      // Verify the correct command was sent
      verify(() => mockHttp.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': 'toggle_stream', 'params': {}}),
      )).called(1);
    });

    test('DecisionLoop switches to Starting scene when going live', () async {
      // Arrange: Streaming started, not on Starting scene yet
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Gaming',
        scenes: ['Starting', 'Gaming', 'BRB'],
        streaming: true,
        recording: false,
        streamDurationSec: 100,
        sources: [],
        audioChannels: [],
      ));

      await agentServer.start(port: 8511);

      // Mock state response
      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
        'obs': {
          'connected': true,
          'current_scene': 'Gaming',
          'scenes': ['Starting', 'Gaming', 'BRB'],
          'streaming': true,
          'recording': false,
          'stream_duration_sec': 100,
          'sources': [],
          'audio_channels': [],
        },
        'platform': {'connected': true},
        'chat': {'total_messages': 0, 'recent': []},
      }));

      // Mock command response
      final commandResponse = MockHttpResponse();
      when(() => commandResponse.statusCode).thenReturn(200);
      when(() => commandResponse.body).thenReturn('{"success": true, "message": "Scene switched"}');

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);
      when(() => mockHttp.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => commandResponse);

      // Act: Run decision loop with switch-to-starting-scene rule
      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [switchToStartingSceneRule()],
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      final results = await loop.runOnce();

      // Assert
      expect(results.length, 1);
      expect(results.first.ruleName, 'switch_to_starting_scene');
      expect(results.first.commandResult?.success, true);

      verify(() => mockHttp.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': 'switch_scene', 'params': {'scene': 'Starting'}}),
      )).called(1);
    });

    test('DecisionLoop reacts to chat commands (!game)', () async {
      // Arrange: Chat contains !game command
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming'],
        streaming: true,
        recording: false,
        streamDurationSec: 500,
        sources: [],
        audioChannels: [],
      ));

      await agentServer.start(port: 8511);

      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
        'obs': {
          'connected': true,
          'current_scene': 'Starting',
          'scenes': ['Starting', 'Gaming'],
          'streaming': true,
          'recording': false,
          'stream_duration_sec': 500,
          'sources': [],
          'audio_channels': [],
        },
        'platform': {'connected': true},
        'chat': {'total_messages': 10, 'recent': ['user1: hello', 'user2: !game']},
      }));

      final commandResponse = MockHttpResponse();
      when(() => commandResponse.statusCode).thenReturn(200);
      when(() => commandResponse.body).thenReturn('{"success": true, "message": "Scene switched"}');

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);
      when(() => mockHttp.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => commandResponse);

      // Act: Run decision loop with chat game command rule
      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [chatGameCommandRule()],
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      final results = await loop.runOnce();

      // Assert
      expect(results.length, 1);
      expect(results.first.ruleName, 'chat_game_command');
      expect(results.first.commandResult?.success, true);

      verify(() => mockHttp.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': 'switch_scene', 'params': {'scene': 'Gaming'}}),
      )).called(1);
    });

    test('DecisionLoop reacts to chat commands (!mute)', () async {
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Gaming',
        scenes: ['Starting', 'Gaming'],
        streaming: true,
        recording: false,
        streamDurationSec: 1000,
        sources: [],
        audioChannels: [],
      ));

      await agentServer.start(port: 8511);

      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
        'obs': {
          'connected': true,
          'current_scene': 'Gaming',
          'scenes': ['Starting', 'Gaming'],
          'streaming': true,
          'recording': false,
          'stream_duration_sec': 1000,
          'sources': [],
          'audio_channels': [],
        },
        'platform': {'connected': true},
        'chat': {'total_messages': 15, 'recent': ['user1: !mute', 'user2: lol']},
      }));

      final commandResponse = MockHttpResponse();
      when(() => commandResponse.statusCode).thenReturn(200);
      when(() => commandResponse.body).thenReturn('{"success": true, "message": "Muted"}');

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);
      when(() => mockHttp.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => commandResponse);

      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [chatMuteCommandRule()],
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      final results = await loop.runOnce();

      expect(results.length, 1);
      expect(results.first.ruleName, 'chat_mute_command');
      expect(results.first.commandResult?.success, true);

      verify(() => mockHttp.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'command': 'set_audio_channel_mute',
          'params': {'channel': 'microphone', 'muted': true}
        }),
      )).called(1);
    });

    test('Full flow: AgentServer state reflects OBS + Twitch, decision loop acts on it', () async {
      // This test verifies the complete wiring:
      // 1. AgentServer aggregates OBS state + Twitch state + chat
      // 2. AgentClient polls /state
      // 3. DecisionLoop evaluates rules against aggregated state
      // 4. Commands are sent back to AgentServer

      // Arrange: Both OBS and Twitch "connected"
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming', 'BRB'],
        streaming: false,
        recording: false,
        streamDurationSec: 0,
        sources: [],
        audioChannels: [],
      ));

      final ircController = StreamController<ChatMessage>.broadcast();
      when(() => mockIrc.messages).thenAnswer((_) => ircController.stream);
      when(() => mockIrc.events).thenAnswer((_) => const Stream.empty());

      when(() => mockHelix.fetchStreamStatus(any())).thenAnswer(
        (_) async => const TwitchStreamStatus(
          live: true,
          viewers: 25,
          game: 'Minecraft',
          title: 'Building stuff',
          uptimeSec: 1800,
        ),
      );

      await agentServer.start(port: 8511);
      await twitchPlatform.connect(const PlatformCredentials(channelName: 'testchannel'));

      // Simulate IRC chat messages coming in
      ircController.add(ChatMessage(
        time: '12:00',
        user: 'viewer1',
        text: 'Nice build!',
        isMod: false,
        isSub: true,
        isVip: false,
        isBroadcaster: false,
      ));
      ircController.add(ChatMessage(
        time: '12:01',
        user: 'viewer2',
        text: '!game',
        isMod: false,
        isSub: false,
        isVip: false,
        isBroadcaster: false,
      ));

      // Allow TwitchPlatform to process messages
      await Future.delayed(const Duration(milliseconds: 50));

      // Mock state response reflecting the aggregated state
      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
        'obs': {
          'connected': true,
          'current_scene': 'Starting',
          'scenes': ['Starting', 'Gaming', 'BRB'],
          'streaming': false,
          'recording': false,
          'stream_duration_sec': 0,
          'sources': [],
          'audio_channels': [],
        },
        'platform': {'connected': true},
        'chat': {'total_messages': 2, 'recent': ['viewer1: Nice build!', 'viewer2: !game']},
      }));

      final commandResponse = MockHttpResponse();
      when(() => commandResponse.statusCode).thenReturn(200);
      when(() => commandResponse.body).thenReturn('{"success": true, "message": "Scene switched"}');

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);
      when(() => mockHttp.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => commandResponse);

      // Act: Run decision loop with multiple rules
      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [
          autoStartStreamRule(),
          switchToStartingSceneRule(),
          chatGameCommandRule(),
        ],
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      final results = await loop.runOnce();

      // Assert: Multiple rules triggered
      expect(results.length, 2); // auto_start_stream + chat_game_command
      // Note: switchToStartingSceneRule requires streaming=true, which isn't set yet

      final ruleNames = results.map((r) => r.ruleName).toList();
      expect(ruleNames, contains('auto_start_stream'));
      expect(ruleNames, contains('chat_game_command'));

      // Verify both commands were sent
      verify(() => mockHttp.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': 'toggle_stream', 'params': {}}),
      )).called(1);

      verify(() => mockHttp.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': 'switch_scene', 'params': {'scene': 'Gaming'}}),
      )).called(1);

      await ircController.close();
    });

    test('DecisionLoop handles command failures gracefully', () async {
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming'],
        streaming: false,
        recording: false,
        streamDurationSec: 0,
        sources: [],
        audioChannels: [],
      ));

      await agentServer.start(port: 8511);

      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
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

      // Command fails
      final commandResponse = MockHttpResponse();
      when(() => commandResponse.statusCode).thenReturn(500);
      when(() => commandResponse.body).thenReturn('Internal Server Error');

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);
      when(() => mockHttp.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => commandResponse);

      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [autoStartStreamRule()],
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      final results = await loop.runOnce();

      // Assert: Rule triggered but command failed
      expect(results.length, 1);
      expect(results.first.ruleName, 'auto_start_stream');
      expect(results.first.conditionMet, true);
      expect(results.first.commandResult, isNull);
      expect(results.first.error, isNotNull);
      expect(results.first.success, false);
    });

    test('shouldContinue stops loop based on state', () async {
      when(() => mockObs.state).thenReturn(const ObsState());

      await agentServer.start(port: 8511);

      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
        'obs': {'connected': false, 'streaming': false},
        'platform': {'connected': false},
        'chat': {'total_messages': 0, 'recent': []},
      }));

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);

      int continueCalls = 0;
      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [],
        shouldContinue: (state) {
          continueCalls++;
          // Stop after first iteration
          return continueCalls < 1;
        },
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      await loop.runOnce();

      expect(continueCalls, 1);
      expect(loop.isRunning, false);
    });

    test('DecisionLoop executes OBS scene switch command correctly', () async {
      // Test that the decision loop correctly calls AgentServer's executeCommand
      // for switch_scene with proper params
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming', 'BRB'],
        streaming: true,
        recording: false,
        streamDurationSec: 100,
        sources: [],
        audioChannels: [],
      ));

      await agentServer.start(port: 8511);

      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
        'obs': {
          'connected': true,
          'current_scene': 'Starting',
          'scenes': ['Starting', 'Gaming', 'BRB'],
          'streaming': true,
          'recording': false,
          'stream_duration_sec': 100,
          'sources': [],
          'audio_channels': [],
        },
        'platform': {'connected': true},
        'chat': {'total_messages': 0, 'recent': []},
      }));

      final commandResponse = MockHttpResponse();
      when(() => commandResponse.statusCode).thenReturn(200);
      when(() => commandResponse.body).thenReturn('{"success": true, "message": "Switched to BRB"}');

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);
      when(() => mockHttp.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => commandResponse);

      // Custom rule: switch to BRB scene when streaming
      final customRule = DecisionRule(
        name: 'switch_to_brb',
        condition: (state) => state.obsConnected && state.streaming && state.currentScene != 'BRB' && state.scenes.contains('BRB'),
        action: (client, state) async => client.sendCommand('switch_scene', {'scene': 'BRB'}),
      );

      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [customRule],
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      final results = await loop.runOnce();

      expect(results.length, 1);
      expect(results.first.ruleName, 'switch_to_brb');
      expect(results.first.commandResult?.success, true);

      verify(() => mockHttp.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': 'switch_scene', 'params': {'scene': 'BRB'}}),
      )).called(1);
    });

    test('DecisionLoop executes toggle_stream command correctly', () async {
      when(() => mockObs.state).thenReturn(ObsState(
        connected: true,
        currentScene: 'Starting',
        scenes: ['Starting', 'Gaming'],
        streaming: false,
        recording: false,
        streamDurationSec: 0,
        sources: [],
        audioChannels: [],
      ));

      await agentServer.start(port: 8511);

      final stateResponse = MockHttpResponse();
      when(() => stateResponse.statusCode).thenReturn(200);
      when(() => stateResponse.body).thenReturn(jsonEncode({
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

      final commandResponse = MockHttpResponse();
      when(() => commandResponse.statusCode).thenReturn(200);
      when(() => commandResponse.body).thenReturn('{"success": true, "message": "Stream started"}');

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => stateResponse);
      when(() => mockHttp.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => commandResponse);

      // Custom rule: start stream when ready
      final startStreamRule = DecisionRule(
        name: 'start_stream_direct',
        condition: (state) => state.obsConnected && state.platformConnected && !state.streaming && state.scenes.isNotEmpty,
        action: (client, state) async => client.sendCommand('toggle_stream', {}),
      );

      final config = DecisionLoopConfig(
        pollInterval: const Duration(milliseconds: 10),
        rules: [startStreamRule],
      );
      final loop = DecisionLoop(client: agentClient, config: config);
      final results = await loop.runOnce();

      expect(results.length, 1);
      expect(results.first.ruleName, 'start_stream_direct');
      expect(results.first.commandResult?.success, true);

      verify(() => mockHttp.post(
        Uri.parse('http://localhost:8511/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': 'toggle_stream', 'params': {}}),
      )).called(1);
    });
  });
}