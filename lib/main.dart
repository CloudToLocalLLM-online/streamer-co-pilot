import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'providers/streamer_bot_provider.dart';
import 'providers/obs_controller.dart';
import 'providers/ai_server.dart';
import 'platforms/twitch_platform.dart';
import 'platforms/stream_platform.dart';
import 'widgets/connection_indicator.dart';
import 'widgets/error_banner.dart';
import 'widgets/compact_overlay.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/chat_tab.dart';
import 'tabs/settings_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final isOverlay = Platform.isLinux &&
      (Platform.environment['OVERLAY_MODE'] == '1' ||
       Platform.environment.containsKey('SCOP_OVERLAY'));

  if (isOverlay) {
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(280, 500),
        minimumSize: Size(200, 200),
        title: 'SCP Overlay',
        center: true,
        alwaysOnTop: true,
        skipTaskbar: true,
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {},
    );
    await windowManager.setResizable(true);
    await windowManager.setOpacity(0.92);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StreamerBotProvider()),
          ChangeNotifierProvider(create: (_) => ObsController()),
        ],
        child: MaterialApp(
          title: 'SCP Overlay',
          theme: botTheme,
          debugShowCheckedModeBanner: false,
          home: const CompactOverlayWindow(),
        ),
      ),
    );
  } else {
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1000, 700),
        minimumSize: Size(600, 400),
        title: 'Streamer Co-Pilot',
        center: true,
      ),
      () async {},
    );

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StreamerBotProvider()),
          ChangeNotifierProvider(create: (_) => ObsController()),
          ChangeNotifierProvider(create: (_) => TwitchPlatform()),
          ChangeNotifierProvider(create: (_) {
            final aiServer = AiServer();
            // Wired after build in _startServices
            return aiServer;
          }),
        ],
        child: const StreamerCoPilotApp(),
      ),
    );
  }
}

class StreamerCoPilotApp extends StatefulWidget {
  const StreamerCoPilotApp({super.key});

  @override
  State<StreamerCoPilotApp> createState() => _StreamerCoPilotAppState();
}

class _StreamerCoPilotAppState extends State<StreamerCoPilotApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServices();
    });
  }

  void _startServices() {
    // Wire providers together
    final obs = context.read<ObsController>();
    final twitch = context.read<TwitchPlatform>();
    final aiServer = context.read<AiServer>();

    aiServer.setObs(obs);
    aiServer.setPlatform(twitch);

    // Start AI server
    aiServer.start(port: 8511);

    // Try auto-connect OBS
    obs.connect();

    // Try auto-connect Twitch if tokens exist
    twitch.auth.loadTokens().then((hasTokens) {
      if (hasTokens) {
        twitch.connect(PlatformCredentials(channelName: null));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streamer Co-Pilot',
      theme: botTheme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StreamerBotProvider>().connectSse();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🎮', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Streamer Co-Pilot'),
            SizedBox(width: 12),
            ConnectionIndicator(),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open compact overlay',
            icon: const Icon(Icons.picture_in_picture, size: 20),
            onPressed: _launchOverlay,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: Consumer<StreamerBotProvider>(
        builder: (_, provider, child) => Column(
          children: [
            const ErrorBanner(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  DashboardTab(),
                  ChatTab(),
                  SettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchOverlay() async {
    await windowManager.hide();
    try {
      await Process.start(
        Platform.resolvedExecutable,
        [],
        environment: { 'SCOP_OVERLAY': '1' },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open overlay: $e')),
        );
        windowManager.show();
      }
    }
  }
}
