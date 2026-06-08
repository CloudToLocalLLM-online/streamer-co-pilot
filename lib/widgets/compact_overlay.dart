import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/streamer_bot_provider.dart';

/// Compact always-on-top overlay window for use while streaming.
/// Shows stream status + scrolling chat in a minimal translucent window.
class CompactOverlayWindow extends StatefulWidget {
  const CompactOverlayWindow({super.key});

  @override
  State<CompactOverlayWindow> createState() => _CompactOverlayWindowState();
}

class _CompactOverlayWindowState extends State<CompactOverlayWindow> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamerBotProvider>(
      builder: (_, provider, _) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xCC0D1117),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          margin: const EdgeInsets.all(4),
          child: Column(
            children: [
              // ── Drag handle / title bar ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0x44000000),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.connected ? Colors.green : Colors.red.shade400,
                        boxShadow: [
                          BoxShadow(
                            color: (provider.connected ? Colors.green : Colors.red.shade400)
                                .withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        provider.streamStatus == 'live'
                            ? '🔴 LIVE'
                            : provider.streamStatus == 'offline'
                                ? '⚫ OFFLINE'
                                : provider.connected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: provider.streamStatus == 'live'
                              ? const Color(0xFFff4444)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    if (provider.viewers > 0)
                      Text(
                        '👁️ ${provider.viewers}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => provider.disconnect(),
                      child: const Icon(Icons.close, size: 14, color: Colors.white38),
                    ),
                  ],
                ),
              ),

              // ── Chat messages ──
              Expanded(
                child: provider.chat.isEmpty
                    ? const Center(
                        child: Text(
                          '💬 Waiting for chat...',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        itemCount: provider.chat.length,
                        itemBuilder: (_, i) {
                          final msg = provider.chat[provider.chat.length - 1 - i];
                          final user = msg.user;
                          final text = msg.text;
                          final isMod = msg.isMod;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12, height: 1.3),
                                children: [
                                  if (isMod)
                                    const WidgetSpan(
                                      child: Text('🛡️ ', style: TextStyle(fontSize: 10)),
                                    ),
                                  TextSpan(
                                    text: '$user: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade200,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: text,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ── Message input ──
              Container(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Chat...',
                          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0x44000000),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            provider.sendMessage(val.trim());
                          }
                        },
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _toggleCompact(context),
                      icon: const Icon(Icons.open_in_full, size: 14, color: Colors.white38),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleCompact(BuildContext context) {
    // Signal to the main window that we want full mode
    windowManager.setSize(const Size(1000, 700));
    windowManager.setAlignment(Alignment.center);
    windowManager.show();
  }
}