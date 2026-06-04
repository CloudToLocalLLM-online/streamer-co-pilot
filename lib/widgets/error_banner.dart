import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streamer_bot_provider.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamerBotProvider>(
      builder: (_, provider, _) {
        if (provider.lastError == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => provider.clearError(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.red.shade900.withValues(alpha: 0.85),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.yellow, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    provider.lastError!,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.close, color: Colors.white54, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}