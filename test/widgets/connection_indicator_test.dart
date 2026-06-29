import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/widgets/connection_indicator.dart';

/// A test subclass that exposes a setter for connected.
class _TestStreamerBotProvider extends StreamerBotProvider {
  bool _testConnected = false;

  @override
  bool get connected => _testConnected;

  void setTestConnected(bool value) {
    _testConnected = value;
    notifyListeners();
  }
}

void main() {
  group('ConnectionIndicator', () {
    testWidgets('Shows connected state', (tester) async {
      final provider = _TestStreamerBotProvider();
      provider.setTestConnected(true);

      await tester.pumpWidget(
        ChangeNotifierProvider<StreamerBotProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: ConnectionIndicator()),
          ),
        ),
      );

      expect(find.text('Connected'), findsOneWidget);
      // The green dot is a Container with BoxShape.circle, hard to find directly
      // but the text is the key indicator
    });

    testWidgets('Shows disconnected state', (tester) async {
      final provider = _TestStreamerBotProvider();
      provider.setTestConnected(false);

      await tester.pumpWidget(
        ChangeNotifierProvider<StreamerBotProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: ConnectionIndicator()),
          ),
        ),
      );

      expect(find.text('Disconnected'), findsOneWidget);
    });
  });
}
