import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sakina_frontend/chat/chat_controller.dart';
import 'package:sakina_frontend/l10n/app_localizations.dart';
import 'package:sakina_frontend/main.dart';
import 'package:sakina_frontend/providers/preferences.dart';
import 'package:sakina_frontend/screens/chat_screen.dart';
import 'package:sakina_frontend/services/api_service.dart';

class _ArabicPreferencesNotifier extends PreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences(locale: Locale('ar'));
}

void main() {
  testWidgets('App shell renders the five primary tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SakinaApp()));

    expect(find.text('Project Sakina'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(
      find.widgetWithText(NavigationDestination, 'Tutoring'),
      findsOneWidget,
    );
    expect(find.widgetWithText(NavigationDestination, 'Quran'), findsOneWidget);
    expect(
        find.widgetWithText(NavigationDestination, 'Prayer'), findsOneWidget);
    expect(
        find.widgetWithText(NavigationDestination, 'Parent'), findsOneWidget);
  });

  testWidgets('Home tab keeps Ask Sakina chat reachable',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SakinaApp()));

    await tester.tap(find.text('Ask Sakina'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('Typing and sending appends a message',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          controller: ChatController(
            backend: _WidgetTestBackend(),
            historyStore: _WidgetTestHistoryStore(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Assalamu alaikum');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Assalamu alaikum'), findsOneWidget);
    expect(find.text('Wa alaikum assalam'), findsOneWidget);
  });

  testWidgets('App supports Arabic localization and RTL direction',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWith(_ArabicPreferencesNotifier.new),
        ],
        child: const SakinaApp(),
      ),
    );

    expect(find.text('مشروع سكينة'), findsOneWidget);
    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.text('اسأل سكينة'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('الرئيسية').first)),
      TextDirection.rtl,
    );
  });

  test('five app locales are supported', () {
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      ['en', 'ar', 'ur', 'tr', 'id'],
    );
    expect(AppLocalizations.rtlLanguages, containsAll(['ar', 'ur']));
  });
}

class _WidgetTestBackend implements ChatBackend {
  @override
  Future<RagResponse> query(String message) async {
    return RagResponse(
      answer: 'Wa alaikum assalam',
      sources: const [],
      confidence: 0.9,
      guardrailTriggered: false,
      processingTimeMs: 10,
    );
  }
}

class _WidgetTestHistoryStore implements ChatHistoryStore {
  @override
  Future<List<ChatMessage>> load() async => const [];

  @override
  Future<void> save(ChatMessage message) async {}

  @override
  Future<void> close() async {}
}
