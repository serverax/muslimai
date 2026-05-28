import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sakina_frontend/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Welcome screen renders key CTAs', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SakinaApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sakina AI'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Learn More'), findsOneWidget);
  });

  testWidgets('Onboarding flow reaches account intro',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SakinaApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Join Waitlist'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });
}
