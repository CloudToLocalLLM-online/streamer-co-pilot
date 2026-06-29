import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_co_pilot/providers/streamer_bot_provider.dart';
import 'package:streamer_co_pilot/widgets/error_banner.dart';

/// A test subclass that exposes a setter for lastError.
class _TestStreamerBotProvider extends StreamerBotProvider {
  String? _testError;

  @override
  String? get lastError => _testError;

  void setTestError(String? error) {
    _testError = error;
    notifyListeners();
  }

  @override
  void clearError() {
    _testError = null;
    notifyListeners();
  }
}

void main() {
  group('ErrorBanner', () {
    testWidgets('Hidden when no error', (tester) async {
      final provider = _TestStreamerBotProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<StreamerBotProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: ErrorBanner()),
          ),
        ),
      );

      // When lastError is null, ErrorBanner returns SizedBox.shrink()
      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('Shows error message when present', (tester) async {
      final provider = _TestStreamerBotProvider();
      provider.setTestError('Test error message');

      await tester.pumpWidget(
        ChangeNotifierProvider<StreamerBotProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: ErrorBanner()),
          ),
        ),
      );

      // Should show the error icon and message
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('Dismiss button clears error', (tester) async {
      final provider = _TestStreamerBotProvider();
      provider.setTestError('Dismiss me');

      await tester.pumpWidget(
        ChangeNotifierProvider<StreamerBotProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: ErrorBanner()),
          ),
        ),
      );

      // Error should be visible
      expect(find.text('Dismiss me'), findsOneWidget);

      // Tap the close icon (which calls provider.clearError())
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Error should be cleared
      expect(find.text('Dismiss me'), findsNothing);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });
  });
}
