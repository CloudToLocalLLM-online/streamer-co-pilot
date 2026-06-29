import 'dart:io' as dart_io;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';
import 'package:streamer_co_pilot/providers/agent_server.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';
import 'package:streamer_co_pilot/platforms/stream_platform.dart';

/// Helper that mimics what _startServices() does in _StreamerCoPilotAppState.
///
/// Wires AgentServer to ObsController and TwitchPlatform, starts the HTTP server,
/// attempts OBS auto-connect, and attempts Twitch auto-connect if tokens exist.
Future<void> startServices({
  required ObsController obs,
  required TwitchPlatform twitch,
  required AgentServer agentServer,
  int port = 8511,
}) async {
  agentServer.setObs(obs);
  agentServer.setPlatform(twitch);

  // Start agent server
  await agentServer.start(port: port);

  // Try auto-connect OBS (will fail gracefully — no OBS running in tests)
  await obs.connect();

  // Try auto-connect Twitch if tokens exist
  final hasTokens = await twitch.auth.loadTokens();
  if (hasTokens) {
    final channelName = await twitch.auth.loadChannelName();
    await twitch.connect(PlatformCredentials(channelName: channelName));
  }
}

void main() {
  group('Provider Wiring (3.1)', () {
    test('3.1.1 — All 4 providers initialize without error', () async {
      // Set up SharedPreferences for StreamerBotProvider
      SharedPreferences.setMockInitialValues({});

      StreamerBotProvider? streamerBot;
      ObsController? obs;
      TwitchPlatform? twitch;
      AgentServer? agentServer;

      expect(() {
        streamerBot = StreamerBotProvider();
      }, returnsNormally);
      expect(() {
        obs = ObsController();
      }, returnsNormally);
      expect(() {
        twitch = TwitchPlatform();
      }, returnsNormally);
      expect(() {
        agentServer = AgentServer();
      }, returnsNormally);

      // Verify all are non-null
      expect(streamerBot, isNotNull);
      expect(obs, isNotNull);
      expect(twitch, isNotNull);
      expect(agentServer, isNotNull);

      // Verify initial states
      expect(obs!.state.connected, false);
      expect(twitch!.connected, false);
      expect(agentServer!.running, false);

      streamerBot!.dispose();
      obs!.dispose();
      twitch!.dispose();
      agentServer!.dispose();
    });

    test('3.1.2 — _startServices() wires AgentServer to ObsController and TwitchPlatform',
        () async {
      SharedPreferences.setMockInitialValues({});

      final obs = ObsController();
      final twitch = TwitchPlatform();
      final agentServer = AgentServer();

      // Manually do what _startServices() does
      agentServer.setObs(obs);
      agentServer.setPlatform(twitch);

      // Verify wiring: buildSnapshot should reflect ObsController state
      final snapshot = agentServer.buildSnapshot();
      expect(snapshot.obs.connected, false);
      expect(snapshot.platformConnected, false);

      // Verify setPlatform wired chat stream
      expect(twitch.chatStream, isNotNull);

      obs.dispose();
      twitch.dispose();
      agentServer.dispose();
    });

    test('3.1.3 — AgentServer starts HTTP server on port 8511', () async {
      SharedPreferences.setMockInitialValues({});

      final obs = ObsController();
      final twitch = TwitchPlatform();
      final agentServer = AgentServer();

      agentServer.setObs(obs);
      agentServer.setPlatform(twitch);

      final started = await agentServer.start(port: 8511);
      expect(started, true);
      expect(agentServer.running, true);
      expect(agentServer.port, 8511);

      // Verify it's actually serving by making a request
      final client = dart_io.HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:8511/health'),
        );
        final response = await request.close();
        expect(response.statusCode, 200);
      } finally {
        client.close();
      }

      agentServer.stop();
      expect(agentServer.running, false);

      obs.dispose();
      twitch.dispose();
      agentServer.dispose();
    });

    test('3.1.4 — ObsController auto-connects on app launch (fails gracefully)',
        () async {
      SharedPreferences.setMockInitialValues({});

      final obs = ObsController();

      // Simulate app launch: call connect() — no OBS running, should fail gracefully
      final connected = await obs.connect();
      expect(connected, false);
      expect(obs.state.connected, false);

      obs.dispose();
    });

    test('3.1.5 — TwitchPlatform auto-connects if tokens exist', () async {
      // Set up SharedPreferences with NO tokens
      SharedPreferences.setMockInitialValues({});

      final twitch = TwitchPlatform();

      // loadTokens should return false when no tokens saved
      final hasTokens = await twitch.auth.loadTokens();
      expect(hasTokens, false);

      // connect should fail gracefully
      final connected = await twitch.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );
      expect(connected, false);
      expect(twitch.connected, false);

      twitch.dispose();
    });

    test('3.1.5b — TwitchPlatform auto-connect with tokens present (no crash)',
        () async {
      // Set up SharedPreferences WITH tokens
      SharedPreferences.setMockInitialValues({
        'twitch_access_token': 'test_access_token',
        'twitch_refresh_token': 'test_refresh_token',
        'twitch_bot_id': '12345',
        'twitch_broadcaster_id': '67890',
        'twitch_channel_name': 'testchannel',
        'twitch_client_id': 'test_client_id',
        'twitch_client_secret': 'test_client_secret',
      });

      final twitch = TwitchPlatform();

      // loadTokens should return true when tokens are saved
      final hasTokens = await twitch.auth.loadTokens();
      expect(hasTokens, true);
      expect(twitch.auth.isAuthenticated, true);

      // connect will attempt IRC connection — in test environment this may
      // succeed (connecting to real Twitch IRC) or fail. Either way it should
      // not crash. We just verify the method completes without throwing.
      await twitch.connect(
        const PlatformCredentials(channelName: 'testchannel'),
      );
      // Don't assert on connected state — it depends on network access

      twitch.dispose();
    });

    test('3.1.2b — Full _startServices() simulation', () async {
      SharedPreferences.setMockInitialValues({});

      final obs = ObsController();
      final twitch = TwitchPlatform();
      final agentServer = AgentServer();

      // Run the full _startServices() equivalent
      await startServices(
        obs: obs,
        twitch: twitch,
        agentServer: agentServer,
        port: 18512, // Use non-standard port to avoid conflicts
      );

      // Verify AgentServer is running
      expect(agentServer.running, true);

      // Verify OBS auto-connect was attempted (failed gracefully)
      expect(obs.state.connected, false);

      // Verify Twitch auto-connect was attempted (no tokens, so skipped)
      expect(twitch.connected, false);

      // Verify wiring is intact
      final snapshot = agentServer.buildSnapshot();
      expect(snapshot.obs.connected, false);
      expect(snapshot.platformConnected, false);

      agentServer.stop();
      obs.dispose();
      twitch.dispose();
      agentServer.dispose();
    });
  });
}
