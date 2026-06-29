import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/tabs/chat_tab.dart';
import 'package:streamer_co_pilot/models/chat_message.dart';

/// A test subclass that exposes setters for connected and chat.
class _TestStreamerBotProvider extends StreamerBotProvider {
  bool _testConnected = false;
  List<ChatMessage> _testChat = [];

  @override
  bool get connected => _testConnected;

  @override
  List<ChatMessage> get chat => _testChat;

  void setConnected(bool value) {
    _testConnected = value;
    notifyListeners();
  }

  void setChat(List<ChatMessage> messages) {
    _testChat = messages;
    notifyListeners();
  }
}

Widget _buildTestApp({
  required StreamerBotProvider botProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<StreamerBotProvider>.value(value: botProvider),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ChatTab()),
    ),
  );
}

void main() {
  group('ChatTab', () {
    testWidgets('Shows "Chat will appear here" when empty', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setChat([]);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      expect(find.text('💬 Chat will appear here...'), findsOneWidget);
    });

    testWidgets('Send button exists', (tester) async {
      final bot = _TestStreamerBotProvider();

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // The send button is a FilledButton with a send icon
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Moderation toolbar visible when connected', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Moderation toggles: Slow, Emote, Subs
      expect(find.text('Slow'), findsOneWidget);
      expect(find.text('Emote'), findsOneWidget);
      expect(find.text('Subs'), findsOneWidget);
      // Clear chat button
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    });

    testWidgets('Moderation toolbar hidden when disconnected', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(false);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Moderation toggles should NOT be visible
      expect(find.text('Slow'), findsNothing);
      expect(find.text('Emote'), findsNothing);
      expect(find.text('Subs'), findsNothing);
      expect(find.byIcon(Icons.delete_sweep), findsNothing);
    });
  });
}
