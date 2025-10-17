// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ozn/src/app.dart';

void main() {
  testWidgets('OZN App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OZNApp());

    // Vérifier que l'app se lance sans erreur
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Onboarding page displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const OZNApp());

    // Vérifier que l'onboarding s'affiche
    expect(find.text('Solidarité à 500m'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
  });

  testWidgets('Navigation to login works', (WidgetTester tester) async {
    await tester.pumpWidget(const OZNApp());

    // Appuyer sur "Passer" pour aller au login
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    // Vérifier qu'on arrive sur la page de login
    expect(find.text('Content de vous revoir !'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}