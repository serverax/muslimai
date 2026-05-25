import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sakina_frontend/main.dart';

void main() {
  testWidgets('Chat screen renders title and input', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SakinaApp()));

    expect(find.text('Project Sakina'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('Typing and sending appends a message', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SakinaApp()));

    await tester.enterText(find.byType(TextField), 'Assalamu alaikum');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Assalamu alaikum'), findsOneWidget);
  });
}
