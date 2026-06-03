import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

// ── SSE event stream client ──────────────────────────────────────────

class SseClient {
  final String url;
  http.Client? _client;

  SseClient(this.url);

  Stream<String> connect() async* {
    _client = http.Client();
    final request = http.Request('GET', Uri.parse('$url/events/stream'));
    final response = await _client!.send(request);

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String currentEvent = '';
    await for (final line in lines) {
      if (line.startsWith('event: ')) {
        currentEvent = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        yield currentEvent.isEmpty ? line.substring(6) : '$currentEvent\x00${line.substring(6)}';
        currentEvent = '';
      }
    }
  }

  void disconnect() {
    _client?.close();
    _client = null;
  }
}

// ── Provider ───────────────────────────────────────────────────────────

class StreamerBotProvider extends ChangeNotifier {
  String _botUrl = 'http://localhost:8510';
  String get botUrl => _botUrl;

  String _streamStatus = 'unknown';
  String get streamStatus => _streamStatus;
  int _viewers = 0;
  int get viewers => _viewers;
  String _game = '';
  String get game => _game;
  String _title = '';
  String get title => _title;

  List<Map<String, dynamic>> _chat = [];
  List<Map<String, dynamic>> get chat => _chat;
  bool _connected = false;
  bool get connected => _connected;

  SseClient? _sse;
  StreamSubscription<String>? _sseSub;
  Timer? _reconnectTimer;
  Process? _serviceProcess;

  void setBotUrl(String url) {
    _botUrl = url;
    notifyListeners();
  }

  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$_botUrl/health'))
          .timeout(const Duration(seconds: 3));
      _connected = res.statusCode == 200;
      notifyListeners();
      return _connected;
    } catch (_) {
      _connected = false;
      notifyListeners();
      return false;
    }
  }

  /// Try to launch the backend service locally.
  Future<bool> _launchService() async {
    // Try known locations
    final possible = [
      '/home/rightguy/streamer-co-pilot-service/.venv/bin/python3',
      '/opt/cloudtolocalllm/streamer-co-pilot-service/.venv/bin/python3',
    ];

    for (final pythonBin in possible) {
      if (await File(pythonBin).exists()) {
        final serviceDir = '${Directory(pythonBin).parent.parent.path}/services/bot-service';
        if (await Directory(serviceDir).exists()) {
          try {
            _serviceProcess = await Process.start(
              pythonBin,
              ['api.py'],
              workingDirectory: serviceDir,
              environment: {
                'TWITCH_BOT_PORT': '8510',
              },
            );
            // Don't wait for it, let it spin up
            _serviceProcess?.stderr
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .listen((line) => debugPrint('[bot] $line'));
            return true;
          } catch (_) {
            return false;
          }
        }
      }
    }
    return false;
  }

  /// Connect via SSE stream. Tries to launch the backend if not running.
  Future<bool> connectSse() async {
    // Health check — try twice with auto-launch between
    var ok = await checkHealth();
    if (!ok) {
      ok = await _launchService();
      if (ok) {
        // Wait for service to boot
        await Future.delayed(const Duration(seconds: 3));
        ok = await checkHealth();
      }
    }
    if (!ok) return false;

    _sse?.disconnect();
    await _sseSub?.cancel();

    _sse = SseClient(_botUrl);
    try {
      _sseSub = _sse!.connect().listen(_handleSseEvent,
          onError: (_) => _scheduleReconnect(),
          onDone: () => _scheduleReconnect());
    } catch (_) {
      _scheduleReconnect();
      return false;
    }

    // Also fetch initial state
    fetchStatus();
    fetchChat();
    _connected = true;
    notifyListeners();
    return true;
  }

  void _handleSseEvent(String raw) {
    // Check for event type prefix (event\x00data format)
    final parts = raw.split('\x00');
    if (parts.length == 2 && parts[0] == 'status') {
      try {
        final data = jsonDecode(parts[1]);
        _streamStatus = data['status'] ?? _streamStatus;
        _title = data['title'] ?? _title;
        _game = data['game'] ?? _game;
        _viewers = data['viewers'] ?? _viewers;
        notifyListeners();
      } catch (_) {}
    } else {
      // Regular chat message
      try {
        final msg = jsonDecode(raw);
        _chat.insert(0, Map<String, dynamic>.from(msg));
        if (_chat.length > 500) _chat = _chat.sublist(0, 200);
        notifyListeners();
      } catch (_) {}
    }
  }

  void _scheduleReconnect() {
    _connected = false;
    notifyListeners();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connectSse();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sseSub?.cancel();
    _sseSub = null;
    _sse?.disconnect();
    _sse = null;
    _connected = false;
    notifyListeners();
  }

  Future<void> fetchStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_botUrl/stream/status'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _streamStatus = data['status'] ?? 'unknown';
        _viewers = data['viewers'] ?? 0;
        _game = data['game'] ?? '';
        _title = data['title'] ?? '';
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchChat() async {
    try {
      final res = await http
          .get(Uri.parse('$_botUrl/chat/recent?count=30'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _chat = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> sendMessage(String text) async {
    try {
      final res = await http
          .post(Uri.parse('$_botUrl/chat/send'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'message': text}))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _serviceProcess?.kill();
    disconnect();
    super.dispose();
  }
}

// ── Theme ──────────────────────────────────────────────────────────────

final botTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: Colors.purple.shade400,
    secondary: Colors.deepPurple.shade300,
    surface: const Color(0xFF1A1A2E),
  ),
  scaffoldBackgroundColor: const Color(0xFF16213E),
  cardColor: const Color(0xFF1A1A2E),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0F3460),
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1A1A2E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.purple.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
    ),
  ),
);

// ── Main ───────────────────────────────────────────────────────────────

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

// ── Main Screen ────────────────────────────────────────────────────────

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
    // Auto-connect on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StreamerBotProvider>();
      provider.connectSse();
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
            _ConnectionIndicator(),
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
      body: TabBarView(
        controller: _tabController,
        children: const [
          DashboardTab(),
          ChatTab(),
          SettingsTab(),
        ],
      ),
    );
  }
}

// ── Connection indicator ──────────────────────────────────────────────

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator();

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamerBotProvider>(
      builder: (_, provider, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: provider.connected ? Colors.green : Colors.red.shade400,
                boxShadow: [
                  BoxShadow(
                    color: (provider.connected
                            ? Colors.green
                            : Colors.red.shade400)
                        .withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              provider.connected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                fontSize: 12,
                color: provider.connected
                    ? Colors.green
                    : Colors.red.shade300,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Dashboard Tab ──────────────────────────────────────────────────────

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamerBotProvider>(
      builder: (_, provider, _) {
        return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            provider.streamStatus == 'live'
                                ? Icons.circle
                                : Icons.circle_outlined,
                            color: provider.streamStatus == 'live'
                                ? Colors.red
                                : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            provider.streamStatus == 'live'
                                ? '🔴 LIVE'
                                : provider.streamStatus == 'offline'
                                    ? '⚫ OFFLINE'
                                    : '❓ Checking...',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (provider.title.isNotEmpty) ...[
                        Text(
                          provider.title,
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (provider.game.isNotEmpty) ...[
                            const Icon(Icons.videogame_asset, size: 16),
                            const SizedBox(width: 4),
                            Text(provider.game),
                            const SizedBox(width: 24),
                          ],
                          const Icon(Icons.visibility, size: 16),
                          const SizedBox(width: 4),
                          Text('${provider.viewers} viewers'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.connectSse(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reconnect'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.fetchStatus(),
                      icon: const Icon(Icons.download),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Chat',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        Expanded(
                          child: provider.chat.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No messages yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: provider.chat.length,
                                  itemBuilder: (_, i) {
                                    final msg = provider.chat[i];
                                    final user = msg['user'] ?? '?';
                                    final text = msg['text'] ?? '';
                                    final isMod = msg['is_mod'] == true;
                                    final time = msg['time'] ?? '';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.3),
                                          children: [
                                            TextSpan(
                                              text: '$time ',
                                              style: const TextStyle(
                                                  color: Colors.grey),
                                            ),
                                            if (isMod)
                                              const WidgetSpan(
                                                child: Text('🛡️ ',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                              ),
                                            TextSpan(
                                              text: '$user: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple.shade200,
                                              ),
                                            ),
                                            TextSpan(
                                              text: text,
                                              style: const TextStyle(
                                                  color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]));
      },
    );
  }
}

// ── Chat Tab ───────────────────────────────────────────────────────────

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await context.read<StreamerBotProvider>().sendMessage(text);
    if (ok) {
      _controller.clear();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: Consumer<StreamerBotProvider>(
              builder: (_, provider, _) {
                final chat = provider.chat;
                if (chat.isEmpty) {
                  return const Center(
                    child: Text('💬 Chat will appear here...',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: chat.length,
                  itemBuilder: (_, i) {
                    final msg = chat[chat.length - 1 - i];
                    final user = msg['user'] ?? '?';
                    final text = msg['text'] ?? '';
                    final isMod = msg['is_mod'] == true;
                    final time = msg['time'] ?? '';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isMod)
                                  const Text('🛡️ ',
                                      style: TextStyle(fontSize: 12)),
                                Text(
                                  user,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade200,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  time,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(text, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Settings Tab ───────────────────────────────────────────────────────

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text =
        context.read<StreamerBotProvider>().botUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bot Connection',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect to the streamer-co-pilot-service. Run the service first, then point this app to it.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Bot API URL',
              hintText: 'http://localhost:8510',
              prefixIcon: Icon(Icons.link),
            ),
            onChanged: (val) {
              context.read<StreamerBotProvider>().setBotUrl(val);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final provider = context.read<StreamerBotProvider>();
                final ok = await provider.connectSse();
                if (ok) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Connected!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Could not connect'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Connect'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Running the Bot',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set PLATFORM in .env (twitch, youtube, kick).\n'
                    'Get credentials from your platform\'s dev portal.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text('2. Run the service:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '# Set PLATFORM=twitch in .env\n'
                      'TWITCH_CLIENT_ID=xxx \\\n'
                      'TWITCH_CLIENT_SECRET=*** \\\n'
                      'BOT_ID=123456 \\\n'
                      'CHANNEL_NAME=your_channel \\\n'
                      'python3 api.py',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '3. Point this app to http://localhost:8510 and click Connect',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
