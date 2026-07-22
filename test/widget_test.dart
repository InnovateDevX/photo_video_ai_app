// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vidzeon/main.dart';

void main() {
  testWidgets('App builds and shows splash screen', (
    WidgetTester tester,
  ) async {
    // Build the app. MyApp now renders SplashScreen as its home route and
    // performs all heavy initialization in the background.
    await tester.pumpWidget(const MyApp());

    // Verify the splash screen renders.
    expect(find.text('Trail AI Studio'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
