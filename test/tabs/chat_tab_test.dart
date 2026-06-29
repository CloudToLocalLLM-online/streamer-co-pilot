import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/tabs/chat_tab.dart';
import 'package:streamer_co_pilot/models/chat_message.dart';

/// A test subclass that exposes setters for connected and chat,
/// and tracks calls to moderation methods.
class _TestStreamerBotProvider extends StreamerBotProvider {
  bool _testConnected = false;
  List<ChatMessage> _testChat = [];

  // Call tracking
  int sendMessageCallCount = 0;
  String? lastSentMessage;
  bool sendMessageResult = true;

  int setChatModeCallCount = 0;
  String? lastSetChatMode;
  bool? lastSetChatModeEnabled;
  bool setChatModeResult = true;

  int clearChatCallCount = 0;
  bool clearChatResult = true;

  int timeoutUserCallCount = 0;
  String? lastTimeoutUser;
  bool timeoutUserResult = true;

  int banUserCallCount = 0;
  String? lastBanUser;
  bool banUserResult = true;

  int unbanUserCallCount = 0;
  String? lastUnbanUser;
  bool unbanUserResult = true;

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

  @override
  Future<bool> sendMessage(String text) async {
    sendMessageCallCount++;
    lastSentMessage = text;
    return sendMessageResult;
  }

  @override
  Future<bool> setChatMode(String mode, bool enabled) async {
    setChatModeCallCount++;
    lastSetChatMode = mode;
    lastSetChatModeEnabled = enabled;
    return setChatModeResult;
  }

  @override
  Future<bool> clearChat() async {
    clearChatCallCount++;
    return clearChatResult;
  }

  @override
  Future<bool> timeoutUser(String user, {int duration = 300}) async {
    timeoutUserCallCount++;
    lastTimeoutUser = user;
    return timeoutUserResult;
  }

  @override
  Future<bool> banUser(String user) async {
    banUserCallCount++;
    lastBanUser = user;
    return banUserResult;
  }

  @override
  Future<bool> unbanUser(String user) async {
    unbanUserCallCount++;
    lastUnbanUser = user;
    return unbanUserResult;
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

    testWidgets('Shows chat messages with badges (mod, sub, vip, broadcaster)',
        (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);
      bot.setChat([
        ChatMessage(
          time: '12:00',
          user: 'moduser',
          text: 'Mod message',
          isMod: true,
        ),
        ChatMessage(
          time: '12:01',
          user: 'subuser',
          text: 'Sub message',
          isSub: true,
        ),
        ChatMessage(
          time: '12:02',
          user: 'vipuser',
          text: 'VIP message',
          isVip: true,
        ),
        ChatMessage(
          time: '12:03',
          user: 'broadcaster',
          text: 'Broadcaster message',
          isBroadcaster: true,
        ),
      ]);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // All usernames should be visible
      expect(find.text('moduser'), findsOneWidget);
      expect(find.text('subuser'), findsOneWidget);
      expect(find.text('vipuser'), findsOneWidget);
      expect(find.text('broadcaster'), findsOneWidget);

      // All messages should be visible
      expect(find.text('Mod message'), findsOneWidget);
      expect(find.text('Sub message'), findsOneWidget);
      expect(find.text('VIP message'), findsOneWidget);
      expect(find.text('Broadcaster message'), findsOneWidget);

      // Badge emojis should be present
      // Note: emoji characters may include variation selectors, so use textContaining
      expect(find.textContaining('🛡'), findsOneWidget); // mod badge
      expect(find.textContaining('⭐'), findsOneWidget); // sub badge
      expect(find.textContaining('💎'), findsOneWidget); // vip badge
      expect(find.textContaining('📺'), findsOneWidget); // broadcaster badge
    });

    testWidgets('Send button exists', (tester) async {
      final bot = _TestStreamerBotProvider();

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Text field clears after successful send', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.sendMessageResult = true;

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Find the text field and type a message
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello chat!');
      await tester.pump();

      // Verify text is entered
      expect(find.text('Hello chat!'), findsOneWidget);

      // Tap the send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify sendMessage was called
      expect(bot.sendMessageCallCount, 1);
      expect(bot.lastSentMessage, 'Hello chat!');

      // Pump past the 500ms delayed scroll animation
      await tester.pump(const Duration(milliseconds: 500));

      // Verify text field was cleared
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, isEmpty);
    });

    testWidgets('Moderation toolbar visible when connected', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      expect(find.text('Slow'), findsOneWidget);
      expect(find.text('Emote'), findsOneWidget);
      expect(find.text('Subs'), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    });

    testWidgets('Moderation toolbar hidden when disconnected', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(false);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      expect(find.text('Slow'), findsNothing);
      expect(find.text('Emote'), findsNothing);
      expect(find.text('Subs'), findsNothing);
      expect(find.byIcon(Icons.delete_sweep), findsNothing);
    });

    testWidgets('Slow/Emote/Subs toggle chips call setChatMode()',
        (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);
      bot.setChatModeResult = true;

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Tap the Slow chip
      await tester.tap(find.text('Slow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bot.setChatModeCallCount, 1);
      expect(bot.lastSetChatMode, 'slow');
      expect(bot.lastSetChatModeEnabled, true);

      // Tap the Emote chip
      await tester.tap(find.text('Emote'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bot.setChatModeCallCount, 2);
      expect(bot.lastSetChatMode, 'emoteonly');
      expect(bot.lastSetChatModeEnabled, true);

      // Tap the Subs chip
      await tester.tap(find.text('Subs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bot.setChatModeCallCount, 3);
      expect(bot.lastSetChatMode, 'subscribers');
      expect(bot.lastSetChatModeEnabled, true);
    });

    testWidgets('Clear chat button calls clearChat()', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);
      bot.clearChatResult = true;

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Tap the clear chat button
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bot.clearChatCallCount, 1);
    });

    testWidgets('Long-press message shows moderation bottom sheet',
        (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);
      bot.setChat([
        ChatMessage(
          time: '12:00',
          user: 'testuser',
          text: 'Test message',
        ),
      ]);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Find the more_horiz icon (moderation action button)
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);

      // Tap the more_horiz icon to open the bottom sheet
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Bottom sheet should show moderation options
      expect(find.text('Moderate testuser'), findsOneWidget);
      expect(find.text('Timeout (5 min)'), findsOneWidget);
      expect(find.text('Ban'), findsOneWidget);
      expect(find.text('Unban'), findsOneWidget);
    });

    testWidgets('Timeout button in bottom sheet works', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);
      bot.timeoutUserResult = true;
      bot.setChat([
        ChatMessage(
          time: '12:00',
          user: 'testuser',
          text: 'Test message',
        ),
      ]);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Open the bottom sheet
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the Timeout button
      await tester.tap(find.text('Timeout (5 min)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bot.timeoutUserCallCount, 1);
      expect(bot.lastTimeoutUser, 'testuser');
    });

    testWidgets('Ban button in bottom sheet works', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);
      bot.banUserResult = true;
      bot.setChat([
        ChatMessage(
          time: '12:00',
          user: 'testuser',
          text: 'Test message',
        ),
      ]);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Open the bottom sheet
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the Ban button
      await tester.tap(find.text('Ban'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bot.banUserCallCount, 1);
      expect(bot.lastBanUser, 'testuser');
    });

    testWidgets('Unban button in bottom sheet works', (tester) async {
      final bot = _TestStreamerBotProvider();
      bot.setConnected(true);
      bot.unbanUserResult = true;
      bot.setChat([
        ChatMessage(
          time: '12:00',
          user: 'testuser',
          text: 'Test message',
        ),
      ]);

      await tester.pumpWidget(_buildTestApp(botProvider: bot));

      // Open the bottom sheet
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the Unban button
      await tester.tap(find.text('Unban'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bot.unbanUserCallCount, 1);
      expect(bot.lastUnbanUser, 'testuser');
    });
  });
}
