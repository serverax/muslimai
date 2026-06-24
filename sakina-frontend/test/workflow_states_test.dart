import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/app/app_state.dart';
import 'package:sakina_frontend/app/app_strings.dart';
import 'package:sakina_frontend/widgets/workflow_states.dart';

void main() {
  testWidgets('LoginRequiredScreen shows required copy and buttons', (tester) async {
    final app = AppState(language: AppLanguage.english, onboardingComplete: true);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginRequiredScreen(appState: app, featureName: 'Bookmarks'),
      ),
    );
    expect(find.text('Login required'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('NotImplementedScreen shows feature name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NotImplementedScreen(featureName: 'Masjid Near Me', reason: 'Map provider needed'),
      ),
    );
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.textContaining('Masjid'), findsWidgets);
  });
}
