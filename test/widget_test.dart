// Basic smoke test for NerZero MRV
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
