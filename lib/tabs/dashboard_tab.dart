import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streamer_bot_provider.dart';

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
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                                    final user = msg.user;
                                    final text = msg.text;
                                    final isMod = msg.isMod;
                                    final time = msg.time;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(fontSize: 13, height: 1.3),
                                          children: [
                                            TextSpan(
                                              text: '$time ',
                                              style: const TextStyle(color: Colors.grey),
                                            ),
                                            if (isMod)
                                              const WidgetSpan(
                                                child: Text('🛡️ ', style: TextStyle(fontSize: 12)),
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
                                              style: const TextStyle(color: Colors.white70),
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
            ],
          ),
        );
      },
    );
  }
}