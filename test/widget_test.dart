import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_co_pilot/main.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';
import 'package:streamer_co_pilot/providers/agent_server.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';

void main() {
  testWidgets('App renders with all tabs', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StreamerBotProvider()),
          ChangeNotifierProvider(create: (_) => ObsController()),
          ChangeNotifierProvider(create: (_) => TwitchPlatform()),
          ChangeNotifierProvider(create: (_) => AgentServer()),
        ],
        child: MaterialApp(
          title: 'Streamer Co-Pilot',
          home: const MainScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Streamer Co-Pilot'), findsOneWidget);
  });
}
