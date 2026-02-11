
import 'package:flutter_test/flutter_test.dart';

import 'package:ayaat/main.dart';

void main() {
  testWidgets('Ayaat app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AyaatApp());

    // Verify the app title is displayed
    expect(find.text('آيات'), findsOneWidget);
    expect(find.text('Ayaat'), findsOneWidget);
  });
}
