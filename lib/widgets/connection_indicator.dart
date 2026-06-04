import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streamer_bot_provider.dart';

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key});

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
                    color: (provider.connected ? Colors.green : Colors.red.shade400)
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
                color: provider.connected ? Colors.green : Colors.red.shade300,
              ),
            ),
          ],
        );
      },
    );
  }
}