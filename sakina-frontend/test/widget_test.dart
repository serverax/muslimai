import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sakina_frontend/app/app_state.dart';
import 'package:sakina_frontend/app/app_strings.dart';
import 'package:sakina_frontend/screens/guest_home_dashboard_screen.dart';
import 'package:sakina_frontend/screens/welcome_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Welcome screen renders key CTAs', (WidgetTester tester) async {
    final app = AppState(language: AppLanguage.english, onboardingComplete: false);
    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(appState: app)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sakina AI'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Learn More'), findsOneWidget);
  });

  testWidgets('Guest home dashboard renders explore section',
      (WidgetTester tester) async {
    final app = AppState(language: AppLanguage.english, onboardingComplete: true);
    await tester.pumpWidget(
      MaterialApp(home: GuestHomeDashboardScreen(appState: app)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('As-salamu alaykum'), findsOneWidget);
    expect(find.text('Explore as guest'), findsOneWidget);
    expect(find.text('Quran Study'), findsWidgets);
  });
}
