import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';
import 'package:streamer_co_pilot/platforms/twitch_platform.dart';
import 'package:streamer_co_pilot/tabs/settings_tab.dart';

Widget _buildTestApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<StreamerBotProvider>(create: (_) => StreamerBotProvider()),
      ChangeNotifierProvider<ObsController>(create: (_) => ObsController()),
      ChangeNotifierProvider<TwitchPlatform>(create: (_) => TwitchPlatform()),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SettingsTab()),
    ),
  );
}

void main() {
  group('SettingsTab', () {
    testWidgets('Platform dropdown shows Twitch/YouTube/Kick', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find the dropdown by its label
      expect(find.text('Platform'), findsOneWidget);

      // Tap the dropdown to open it
      await tester.tap(find.text('Platform'));
      await tester.pumpAndSettle();

      // Now the dropdown items should be visible
      expect(find.text('Twitch'), findsWidgets); // may appear in both dropdown and items
      expect(find.text('YouTube (coming soon)'), findsOneWidget);
      expect(find.text('Kick (coming soon)'), findsOneWidget);
    });

    testWidgets('Twitch Client ID/Secret fields exist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Twitch Client ID'), findsOneWidget);
      expect(find.text('Twitch Client Secret'), findsOneWidget);
    });

    testWidgets('Channel Name field exists', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Channel Name'), findsOneWidget);
    });

    testWidgets('OBS host/port/password fields exist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
      expect(find.text('Password (optional)'), findsOneWidget);
    });

    testWidgets('AI Interface section shows API endpoints', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // AI Interface section header
      expect(find.text('AI Interface'), findsOneWidget);
      // The API text is a single multi-line Text widget, so use textContaining
      expect(find.textContaining('http://localhost:8511'), findsOneWidget);
      expect(find.textContaining('/state'), findsOneWidget);
      expect(find.textContaining('/command'), findsOneWidget);
      expect(find.textContaining('/overlay'), findsOneWidget);
    });
  });
}
