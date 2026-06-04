import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isMod)
                                  const Text('🛡️ ', style: TextStyle(fontSize: 12)),
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
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
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