import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/main.dart';

void main() {
  testWidgets('Streamer Co-Pilot app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const StreamerCoPilotApp());
    expect(find.text('Streamer Co-Pilot'), findsOneWidget);
  });
}
