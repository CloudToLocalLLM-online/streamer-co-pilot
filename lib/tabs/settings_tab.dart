import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streamer_bot_provider.dart';

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
    _urlController.text = context.read<StreamerBotProvider>().botUrl;
    context.read<StreamerBotProvider>().addListener(_onProviderChange);
  }

  void _onProviderChange() {
    if (_urlController.text != context.read<StreamerBotProvider>().botUrl) {
      _urlController.text = context.read<StreamerBotProvider>().botUrl;
    }
  }

  @override
  void dispose() {
    context.read<StreamerBotProvider>().removeListener(_onProviderChange);
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
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
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
          const SizedBox(height: 32),
          const Text(
            'Quick Start',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
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
                color: Colors.green,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}