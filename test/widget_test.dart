import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayaat/main.dart';

void main() {
  testWidgets('Ayaat app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AyaatApp());

    // Initially it shows a CircularProgressIndicator while checking app state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
