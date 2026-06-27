import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_co_pilot/main.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';
import 'package:streamer_co_pilot/providers/ai_server.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';

void main() {
  testWidgets('App renders with all tabs', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StreamerBotProvider()),
          ChangeNotifierProvider(create: (_) => ObsController()),
          ChangeNotifierProvider(create: (_) => TwitchPlatform()),
          ChangeNotifierProvider(create: (_) => AiServer()),
        ],
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
