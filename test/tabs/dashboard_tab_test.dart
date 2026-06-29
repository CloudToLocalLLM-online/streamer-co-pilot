import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';
import 'package:streamer_co_pilot/tabs/dashboard_tab.dart';
import 'package:streamer_co_pilot/models/chat_message.dart';

// ── Test helpers ──

class _TestStreamerBotProvider extends StreamerBotProvider {
  String _testStreamStatus = 'unknown';
  List<ChatMessage> _testChat = [];
  String _testTitle = '';
  String _testGame = '';
  int _testViewers = 0;

  @override
  String get streamStatus => _testStreamStatus;
  @override
  String get title => _testTitle;
  @override
  String get game => _testGame;
  @override
  int get viewers => _testViewers;
  @override
  List<ChatMessage> get chat => _testChat;

  void setStreamStatus(String status) {
    _testStreamStatus = status;
    notifyListeners();
  }

  void setChat(List<ChatMessage> messages) {
    _testChat = messages;
    notifyListeners();
  }

  void setTitle(String t) {
    _testTitle = t;
    notifyListeners();
  }

  void setGame(String g) {
    _testGame = g;
    notifyListeners();
  }

  void setViewers(int v) {
    _testViewers = v;
    notifyListeners();
  }
}

class _TestObsController extends ObsController {
  ObsState _testState = const ObsState();

  @override
  ObsState get state => _testState;

  void setState(ObsState newState) {
    _testState = newState;
    notifyListeners();
  }
}

class _TestTwitchPlatform extends TwitchPlatform {
  bool _testConnected = false;

  @override
  bool get connected => _testConnected;

  void setConnected(bool value) {
    _testConnected = value;
    notifyListeners();
  }
}

Widget _buildTestApp({
  required StreamerBotProvider botProvider,
  required ObsController obsController,
  required TwitchPlatform twitchPlatform,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<StreamerBotProvider>.value(value: botProvider),
      ChangeNotifierProvider<ObsController>.value(value: obsController),
      ChangeNotifierProvider<TwitchPlatform>.value(value: twitchPlatform),
    ],
    child: const MaterialApp(
      home: Scaffold(body: DashboardTab()),
    ),
  );
}

void main() {
  group('DashboardTab', () {
    testWidgets('Shows stream status LIVE', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setStreamStatus('live');
      bot.setTitle('My Stream');
      bot.setGame('Just Chatting');
      bot.setViewers(42);

      await tester.pumpWidget(_buildTestApp(
        botProvider: bot,
        obsController: _TestObsController(),
        twitchPlatform: _TestTwitchPlatform(),
      ));

      expect(find.text('🔴 LIVE'), findsOneWidget);
      expect(find.text('My Stream'), findsOneWidget);
      expect(find.text('Just Chatting'), findsOneWidget);
      expect(find.text('42 viewers'), findsOneWidget);
    });

    testWidgets('Shows stream status OFFLINE', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setStreamStatus('offline');

      await tester.pumpWidget(_buildTestApp(
        botProvider: bot,
        obsController: _TestObsController(),
        twitchPlatform: _TestTwitchPlatform(),
      ));

      expect(find.text('⚫ OFFLINE'), findsOneWidget);
    });

    testWidgets('Shows stream status Checking', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setStreamStatus('unknown');

      await tester.pumpWidget(_buildTestApp(
        botProvider: bot,
        obsController: _TestObsController(),
        twitchPlatform: _TestTwitchPlatform(),
      ));

      expect(find.text('❓ Checking...'), findsOneWidget);
    });

    testWidgets('Shows OBS connection status - connected', (tester) async {
      final obs = _TestObsController();
      obs.setState(const ObsState(
        connected: true,
        currentScene: 'Game Scene',
        scenes: ['Game Scene', 'BRB'],
        sources: [
          ObsSourceState(name: 'Camera', enabled: true, itemId: 1),
          ObsSourceState(name: 'Mic', enabled: false, itemId: 2),
        ],
        streaming: true,
        recording: false,
      ));

      await tester.pumpWidget(_buildTestApp(
        botProvider: _TestStreamerBotProvider(),
        obsController: obs,
        twitchPlatform: _TestTwitchPlatform(),
      ));

      // OBS Studio title
      expect(find.text('OBS Studio'), findsOneWidget);
      // Check icon
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('Shows OBS connection status - disconnected', (tester) async {
      final obs = _TestObsController();
      obs.setState(const ObsState(connected: false));

      await tester.pumpWidget(_buildTestApp(
        botProvider: _TestStreamerBotProvider(),
        obsController: obs,
        twitchPlatform: _TestTwitchPlatform(),
      ));

      expect(find.text('OBS Studio'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsWidgets);
    });

    testWidgets('Shows OBS scene name when connected', (tester) async {
      final obs = _TestObsController();
      obs.setState(const ObsState(
        connected: true,
        currentScene: 'Game Scene',
        scenes: ['Game Scene', 'BRB'],
      ));

      await tester.pumpWidget(_buildTestApp(
        botProvider: _TestStreamerBotProvider(),
        obsController: obs,
        twitchPlatform: _TestTwitchPlatform(),
      ));

      expect(find.text('Scene: Game Scene'), findsOneWidget);
      expect(find.text('2 scenes'), findsOneWidget);
    });

    testWidgets('Shows OBS source chips with enabled/disabled state', (tester) async {
      final obs = _TestObsController();
      obs.setState(const ObsState(
        connected: true,
        currentScene: 'Game Scene',
        scenes: ['Game Scene'],
        sources: [
          ObsSourceState(name: 'Camera', enabled: true, itemId: 1),
          ObsSourceState(name: 'Mic', enabled: false, itemId: 2),
        ],
      ));

      await tester.pumpWidget(_buildTestApp(
        botProvider: _TestStreamerBotProvider(),
        obsController: obs,
        twitchPlatform: _TestTwitchPlatform(),
      ));

      // Sources header
      expect(find.text('Sources:'), findsOneWidget);
      // Source names
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Mic'), findsOneWidget);
      // Visibility icons
      expect(find.byIcon(Icons.visibility), findsWidgets);
      expect(find.byIcon(Icons.visibility_off), findsWidgets);
    });

    testWidgets('Shows Twitch connection status - connected', (tester) async {
      final twitch = _TestTwitchPlatform();
      twitch.setConnected(true);

      await tester.pumpWidget(_buildTestApp(
        botProvider: _TestStreamerBotProvider(),
        obsController: _TestObsController(),
        twitchPlatform: twitch,
      ));

      expect(find.text('Twitch'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('Shows Twitch connection status - disconnected', (tester) async {
      final twitch = _TestTwitchPlatform();
      twitch.setConnected(false);

      await tester.pumpWidget(_buildTestApp(
        botProvider: _TestStreamerBotProvider(),
        obsController: _TestObsController(),
        twitchPlatform: twitch,
      ));

      expect(find.text('Twitch'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
    });

    testWidgets('Shows "No messages yet" when chat empty', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setChat([]);

      await tester.pumpWidget(_buildTestApp(
        botProvider: bot,
        obsController: _TestObsController(),
        twitchPlatform: _TestTwitchPlatform(),
      ));

      expect(find.text('No messages yet'), findsOneWidget);
    });
  });
}
