import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/streamer_bot_provider.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  // Moderation state toggles
  bool _slowMode = false;
  bool _emoteOnly = false;
  bool _subOnly = false;

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

  void _showModMenu(BuildContext context, ChatMessage msg) {
    final user = msg.user;
    final provider = context.read<StreamerBotProvider>();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Moderate $user',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: Colors.orange),
              title: const Text('Timeout (5 min)'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await provider.timeoutUser(user);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? '$user timed out' : 'Timeout failed')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Ban'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await provider.banUser(user);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? '$user banned' : 'Ban failed')),
                  );
                }
              },
            ),
            if (msg.isMod)
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.amber),
                title: const Text('Unmod'),
                onTap: () async {
                  Navigator.pop(ctx);
                  // Unmod not exposed as separate endpoint; skip
                },
              ),
            ListTile(
              leading: const Icon(Icons.undo, color: Colors.teal),
              title: const Text('Unban'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await provider.unbanUser(user);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? '$user unbanned' : 'Unban failed')),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // ── Moderation toolbar ──
          Consumer<StreamerBotProvider>(
            builder: (_, provider, _) {
              if (!provider.connected) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _ModToggle(
                      icon: Icons.slow_motion_video,
                      label: 'Slow',
                      active: _slowMode,
                      onChanged: (v) async {
                        final ok = await provider.setChatMode('slow', v);
                        if (ok) setState(() => _slowMode = v);
                      },
                    ),
                    const SizedBox(width: 4),
                    _ModToggle(
                      icon: Icons.emoji_emotions,
                      label: 'Emote',
                      active: _emoteOnly,
                      onChanged: (v) async {
                        final ok = await provider.setChatMode('emoteonly', v);
                        if (ok) setState(() => _emoteOnly = v);
                      },
                    ),
                    const SizedBox(width: 4),
                    _ModToggle(
                      icon: Icons.people,
                      label: 'Subs',
                      active: _subOnly,
                      onChanged: (v) async {
                        final ok = await provider.setChatMode('subscribers', v);
                        if (ok) setState(() => _subOnly = v);
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      tooltip: 'Clear chat',
                      onPressed: () async {
                        final ok = await provider.clearChat();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Chat cleared' : 'Clear failed')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Chat messages ──
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
                    final user = msg.user;
                    final text = msg.text;
                    final isMod = msg.isMod;
                    final isSub = msg.isSub;
                    final isVip = msg.isVip;
                    final isBroadcaster = msg.isBroadcaster;
                    final time = msg.time;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Badges
                                if (isBroadcaster)
                                  const Text('📺 ', style: TextStyle(fontSize: 12)),
                                if (isMod)
                                  const Text('🛡️ ', style: TextStyle(fontSize: 12)),
                                if (isSub)
                                  const Text('⭐ ', style: TextStyle(fontSize: 12)),
                                if (isVip)
                                  const Text('💎 ', style: TextStyle(fontSize: 12)),
                                Text(
                                  user,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isBroadcaster
                                        ? Colors.amber
                                        : isMod
                                            ? Colors.purple.shade200
                                            : isSub
                                                ? Colors.green.shade300
                                                : Colors.blue.shade200,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  time,
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(text, style: const TextStyle(fontSize: 14)),
                            // Moderation actions on long-press
                            if (provider.connected)
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () => _showModMenu(context, msg),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Icon(Icons.more_horiz,
                                        size: 16, color: Colors.grey.shade600),
                                  ),
                                ),
                              ),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

/// Small toggle chip for chat mode controls
class _ModToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final ValueChanged<bool> onChanged;

  const _ModToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: active,
      onSelected: onChanged,
      visualDensity: VisualDensity.compact,
      showCheckmark: false,
      selectedColor: Colors.purple.shade800.withValues(alpha: 0.4),
    );
  }
}