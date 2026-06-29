import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';
import 'package:streamer_co_pilot/platforms/twitch_auth.dart';
import 'package:streamer_co_pilot/tabs/settings_tab.dart';

/// A test subclass that exposes setters for OBS state.
class _TestObsController extends ObsController {
  bool _testConnected = false;

  int connectCallCount = 0;
  int disconnectCallCount = 0;

  @override
  ObsState get state => ObsState(
        connected: _testConnected,
        currentScene: _testConnected ? 'Test Scene' : null,
      );

  void setConnected(bool value) {
    _testConnected = value;
    notifyListeners();
  }

  @override
  Future<bool> connect() async {
    connectCallCount++;
    _testConnected = true;
    notifyListeners();
    return true;
  }

  @override
  void disconnect() {
    disconnectCallCount++;
    _testConnected = false;
    notifyListeners();
  }
}

/// A test TwitchAuth that we can control.
class _TestTwitchAuth extends TwitchAuth {
  bool _isAuthenticated = false;
  String? _clientId;
  String? _channelName;

  @override
  bool get isAuthenticated => _isAuthenticated;
  @override
  String? get accessToken => _isAuthenticated ? 'test-token' : null;
  @override
  String? get clientId => _clientId;

  void setAuthenticated(bool value, {String? clientId}) {
    _isAuthenticated = value;
    _clientId = value ? (clientId ?? 'test-client-id') : null;
    notifyListeners();
  }

  void setChannelName(String name) {
    _channelName = name;
  }

  @override
  String get authorizationUrl =>
      'https://id.twitch.tv/oauth2/authorize?client_id=test';
  @override
  void configure(
      {String? clientId, String? clientSecret, String? redirectUri}) {}
  @override
  Future<bool> exchangeCode(String code) async => true;
  @override
  Future<bool> refreshToken() async => true;
  @override
  Future<bool> ensureValidToken() async => _isAuthenticated;
  @override
  Future<void> clearTokens() async {
    _isAuthenticated = false;
    _clientId = null;
    notifyListeners();
  }
  @override
  Future<bool> loadTokens() async => _isAuthenticated;
  @override
  Future<bool> loadCredentials() async => _isAuthenticated;
  @override
  Future<void> saveCredentials() async {}
  @override
  Future<String?> loadChannelName() async => _channelName;
  @override
  Future<void> saveChannelName(String name) async {
    _channelName = name;
  }
  @override
  String? get botId => null;
  @override
  String? get broadcasterId => null;
  @override
  void setBroadcasterId(String id) {}
}

/// A test TwitchPlatform that uses a controllable _TestTwitchAuth.
class _TestTwitchPlatform extends TwitchPlatform {
  final _TestTwitchAuth _testAuth;

  _TestTwitchPlatform({_TestTwitchAuth? auth})
      : _testAuth = auth ?? _TestTwitchAuth(),
        super();

  _TestTwitchAuth get testAuth => _testAuth;

  @override
  TwitchAuth get auth => _testAuth;
}

Widget _buildTestApp({
  ObsController? obsController,
  TwitchPlatform? twitchPlatform,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<StreamerBotProvider>(
        create: (_) => StreamerBotProvider(),
      ),
      ChangeNotifierProvider<ObsController>(
        create: (_) => obsController ?? ObsController(),
      ),
      ChangeNotifierProvider<TwitchPlatform>(
        create: (_) => twitchPlatform ?? TwitchPlatform(),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SettingsTab()),
    ),
  );
}

void main() {
  group('SettingsTab', () {
    testWidgets('Platform dropdown shows Twitch/YouTube/Kick', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Platform'), findsOneWidget);

      await tester.tap(find.text('Platform'));
      await tester.pumpAndSettle();

      expect(find.text('Twitch'), findsWidgets);
      expect(find.text('YouTube (coming soon)'), findsOneWidget);
      expect(find.text('Kick (coming soon)'), findsOneWidget);
    });

    testWidgets('Twitch Client ID/Secret fields exist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Twitch Client ID'), findsOneWidget);
      expect(find.text('Twitch Client Secret'), findsOneWidget);
    });

    testWidgets('Channel Name field exists', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Channel Name'), findsOneWidget);
    });

    testWidgets('"Authorize with Twitch" button visible when not authenticated',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final twitch = _TestTwitchPlatform();
      twitch.testAuth.setAuthenticated(false);

      await tester.pumpWidget(_buildTestApp(twitchPlatform: twitch));
      await tester.pumpAndSettle();

      expect(find.text('Authorize with Twitch'), findsOneWidget);
      expect(find.text('Connected to Twitch'), findsNothing);
      expect(find.text('Disconnect Twitch'), findsNothing);
    });

    testWidgets('"Connected to Twitch" shown when authenticated',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final twitch = _TestTwitchPlatform();
      twitch.testAuth.setAuthenticated(true);

      await tester.pumpWidget(_buildTestApp(twitchPlatform: twitch));
      await tester.pumpAndSettle();

      expect(find.text('Connected to Twitch'), findsOneWidget);
      expect(find.text('Authorize with Twitch'), findsNothing);
    });

    testWidgets('"Disconnect Twitch" button shown when authenticated',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final twitch = _TestTwitchPlatform();
      twitch.testAuth.setAuthenticated(true);

      await tester.pumpWidget(_buildTestApp(twitchPlatform: twitch));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Twitch'), findsOneWidget);
    });

    testWidgets('OBS host/port/password fields exist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
      expect(find.text('Password (optional)'), findsOneWidget);
    });

    testWidgets('OBS Connect/Disconnect buttons work', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final obs = _TestObsController();

      await tester.pumpWidget(_buildTestApp(obsController: obs));
      await tester.pumpAndSettle();

      // Scroll down to find OBS section
      await tester.scrollUntilVisible(
        find.text('Connect OBS'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('OBS Disconnected'), findsOneWidget);
      expect(find.text('OBS Connected'), findsNothing);

      expect(find.text('Connect OBS'), findsOneWidget);
      await tester.tap(find.text('Connect OBS'));
      await tester.pumpAndSettle();

      expect(obs.connectCallCount, 1);
      expect(find.text('OBS Connected'), findsOneWidget);
      expect(find.text('OBS Disconnected'), findsNothing);

      // Use at(0) to get the first OutlinedButton with 'Disconnect' (OBS one)
      final obsDisconnectButton = find.widgetWithText(OutlinedButton, 'Disconnect').at(0);
      await tester.ensureVisible(obsDisconnectButton);
      await tester.pumpAndSettle();
      await tester.tap(obsDisconnectButton);
      await tester.pumpAndSettle();

      expect(obs.disconnectCallCount, 1);
      expect(find.text('OBS Disconnected'), findsOneWidget);
      expect(find.text('OBS Connected'), findsNothing);
    });

    testWidgets('OBS WebSocket setup guide is displayed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('OBS WebSocket Setup'), findsOneWidget);
      expect(find.textContaining('1. Open OBS Studio'), findsOneWidget);
      expect(find.textContaining('2. Go to Tools'), findsOneWidget);
      expect(find.textContaining('3. Check "Enable WebSocket Server"'), findsOneWidget);
    });

    testWidgets('AI Interface section shows API endpoints', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('AI Interface'), findsOneWidget);
      expect(find.textContaining('http://localhost:8511'), findsOneWidget);
      expect(find.textContaining('/state'), findsOneWidget);
      expect(find.textContaining('/command'), findsOneWidget);
      expect(find.textContaining('/overlay'), findsOneWidget);
    });

    testWidgets('Legacy Connect/Disconnect buttons exist and Connect shows feedback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Legacy Bot Connection'), findsOneWidget);
      expect(find.text('Bot API URL'), findsOneWidget);

      // Scroll to the Legacy section
      await tester.ensureVisible(find.text('Legacy Bot Connection'));
      await tester.pumpAndSettle();

      // The Legacy Connect button
      expect(find.text('Connect'), findsOneWidget);

      // Tap Connect (will fail since no server running)
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Connection failed'), findsOneWidget);

      // The Legacy Disconnect button exists (there are 2 OutlinedButtons with "Disconnect")
      expect(
        find.widgetWithText(OutlinedButton, 'Disconnect'),
        findsAtLeast(2),
      );
    });
  });
}
