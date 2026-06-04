import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_co_pilot/main.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';

void main() {
  testWidgets('App renders with all tabs', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => StreamerBotProvider(),
        child: const StreamerCoPilotApp(),
      ),
    );

    // Should show the three tabs
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Streamer Co-Pilot'), findsOneWidget);
  });
}