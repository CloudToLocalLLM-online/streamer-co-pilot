import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'providers/streamer_bot_provider.dart';
import 'widgets/connection_indicator.dart';
import 'widgets/error_banner.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/chat_tab.dart';
import 'tabs/settings_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
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
    ChangeNotifierProvider(
      create: (_) => StreamerBotProvider(),
      child: const StreamerCoPilotApp(),
    ),
  );
}

class StreamerCoPilotApp extends StatelessWidget {
  const StreamerCoPilotApp({super.key});

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
        builder: (_, provider, _) => Column(
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
}