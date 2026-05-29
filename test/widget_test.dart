import 'package:flutter_test/flutter_test.dart';

import 'package:speakify/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SpeakifyApp());

    // Verify the app name is displayed on the placeholder screen.
    expect(find.text('Speakify'), findsOneWidget);
    expect(find.text('Multi-device audio sync'), findsOneWidget);
  });
}
