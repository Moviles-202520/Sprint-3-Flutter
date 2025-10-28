// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:punto_neutro/presentation/screens/PuntoNeutroApp.dart';

void main() {
  testWidgets('App renders login screen title', (WidgetTester tester) async {
    // Initialize bindings and Supabase (required by Auth repository used in app root).
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://oikdnxujjmkbewdhpyor.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9pa2RueHVqam1rYmV3ZGhweW9yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0MDU0MjksImV4cCI6MjA3NDk4MTQyOX0.htw3cdc-wFcBjKKPP4aEC9K9xBEnvPULMToP_PIuaLI',
    );
    // Build the app root and trigger a frame.
  await tester.pumpWidget(const PuntoNeutroApp());
  // Avoid pumpAndSettle() to prevent waiting on long-lived timers.
  await tester.pump(const Duration(milliseconds: 100));

    // Verify that the login screen title is present.
    expect(find.text('Punto Neutro'), findsOneWidget);
    expect(find.text('Fighting misinformation'), findsOneWidget);
  });
}
