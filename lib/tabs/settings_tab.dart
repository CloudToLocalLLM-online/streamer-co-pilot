import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/streamer_bot_provider.dart';
import '../providers/obs_controller.dart';
import '../platforms/twitch_platform.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _urlController = TextEditingController();
  final _obsHostController = TextEditingController(text: 'localhost');
  final _obsPortController = TextEditingController(text: '4455');
  final _obsPasswordController = TextEditingController();
  final _twitchClientIdController = TextEditingController();
  final _twitchClientSecretController = TextEditingController();
  final _channelNameController = TextEditingController();
  StreamerBotProvider? _botProvider;

  @override
  void initState() {
    super.initState();
    _botProvider = context.read<StreamerBotProvider>();
    _urlController.text = _botProvider!.botUrl;
    _botProvider!.addListener(_onProviderChange);
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final twitch = context.read<TwitchPlatform>();
    final hasCreds = await twitch.auth.loadCredentials();
    if (hasCreds) {
      _twitchClientIdController.text = twitch.auth.clientId ?? '';
    }
    final channelName = await twitch.auth.loadChannelName();
    if (channelName != null) {
      _channelNameController.text = channelName;
    }
  }

  void _onProviderChange() {
    final provider = _botProvider;
    if (provider != null && _urlController.text != provider.botUrl) {
      _urlController.text = provider.botUrl;
    }
  }

  @override
  void dispose() {
    _botProvider?.removeListener(_onProviderChange);
    _botProvider = null;
    _urlController.dispose();
    _obsHostController.dispose();
    _obsPortController.dispose();
    _obsPasswordController.dispose();
    _twitchClientIdController.dispose();
    _twitchClientSecretController.dispose();
    _channelNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Platform Section ──
          const Text(
            'Streaming Platform',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your platform and connect with your credentials.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Platform selector
          DropdownButtonFormField<String>(
            initialValue: 'Twitch',
            decoration: const InputDecoration(
              labelText: 'Platform',
              prefixIcon: Icon(Icons.live_tv),
            ),
            items: const [
              DropdownMenuItem(value: 'Twitch', child: Text('Twitch')),
              DropdownMenuItem(value: 'YouTube', child: Text('YouTube (coming soon)')),
              DropdownMenuItem(value: 'Kick', child: Text('Kick (coming soon)')),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          // Twitch credentials
          TextField(
            controller: _twitchClientIdController,
            decoration: const InputDecoration(
              labelText: 'Twitch Client ID',
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _twitchClientSecretController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Twitch Client Secret',
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _channelNameController,
            decoration: const InputDecoration(
              labelText: 'Channel Name',
              hintText: 'your_channel',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),

          // Twitch OAuth
          Consumer<TwitchPlatform>(
            builder: (_, twitch, child) {
              if (twitch.auth.isAuthenticated) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        const Text('Connected to Twitch', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await twitch.auth.clearTokens();
                          twitch.disconnect();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Disconnected from Twitch')),
                          );
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Disconnect Twitch'),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _connectTwitch(),
                      icon: const Icon(Icons.login),
                      label: const Text('Authorize with Twitch'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Opens a browser window to authorize the app.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              );
            },
          ),

          const Divider(height: 40),

          // ── OBS Section ──
          const Text(
            'OBS Studio',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect to OBS via obs-websocket (built into OBS 28+).',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _obsHostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: 'localhost',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _obsPortController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '4455',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obsPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password (optional)',
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 16),

          Consumer<ObsController>(
            builder: (_, obs, child) {
              return Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        obs.state.connected ? Icons.check_circle : Icons.error_outline,
                        color: obs.state.connected ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        obs.state.connected ? 'OBS Connected' : 'OBS Disconnected',
                        style: TextStyle(
                          color: obs.state.connected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (obs.state.connected) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Scene: ${obs.state.currentScene ?? "N/A"}  |  '
                      'Stream: ${obs.state.streaming ? "LIVE" : "OFF"}  |  '
                      'Rec: ${obs.state.recording ? "ON" : "OFF"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            obs.configure(
                              host: _obsHostController.text,
                              port: int.tryParse(_obsPortController.text) ?? 4455,
                              password: _obsPasswordController.text,
                            );
                            obs.connect();
                          },
                          icon: const Icon(Icons.wifi),
                          label: const Text('Connect OBS'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => obs.disconnect(),
                          icon: const Icon(Icons.wifi_off),
                          label: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // OBS setup guide
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OBS WebSocket Setup',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Open OBS Studio\n'
                          '2. Go to Tools → WebSocket Server Settings\n'
                          '3. Check "Enable WebSocket Server"\n'
                          '4. Set port (default: 4455)\n'
                          '5. Set a password (optional)\n'
                          '6. Click OK\n'
                          '7. Enter the same host/port/password above',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.green,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(height: 40),

          // ── Agent Server Section ──
          const Text(
            'Agent Interface',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hermes Agent or OpenClaw connects here to read stream state and send commands.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Agent API: http://localhost:8511\n'
              'GET  /state     → Full stream + OBS snapshot\n'
              'POST /command   → Execute action\n'
              'GET  /overlay   → OBS browser source',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.green,
                height: 1.5,
              ),
            ),
          ),

          const Divider(height: 40),

          // ── Legacy Bot Connection ──
          const Text(
            'Legacy Bot Connection',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final provider = context.read<StreamerBotProvider>();
                    final ok = await provider.connectSse();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? '✅ Connected!' : '❌ Connection failed'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.wifi),
                  label: const Text('Connect'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<StreamerBotProvider>().disconnect();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Disconnected'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.wifi_off),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _connectTwitch() async {
    final twitch = context.read<TwitchPlatform>();
    final clientId = _twitchClientIdController.text.trim();
    final clientSecret = _twitchClientSecretController.text.trim();
    final channelName = _channelNameController.text.trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your Twitch Client ID and Secret first')),
      );
      return;
    }

    twitch.configure(clientId: clientId, clientSecret: clientSecret);

    // Save credentials and channel name
    await twitch.auth.saveCredentials();
    if (channelName.isNotEmpty) {
      await twitch.auth.saveChannelName(channelName);
    }

    final url = twitch.authorizationUrl;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
