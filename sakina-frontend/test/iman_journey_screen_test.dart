import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/screens/iman_journey_screen.dart';
import 'package:sakina_frontend/services/api_service.dart';

class _FakeApiService extends ApiService {
  _FakeApiService()
      : super(
          baseUrl: 'http://test',
        );

  ImanJourneyPrivacySettingsDto privacy = const ImanJourneyPrivacySettingsDto(
    personalizationEnabled: true,
    remindersEnabled: true,
    storeJourneyEnabled: true,
  );

  final List<ImanDuaItemDto> _duas = [];

  @override
  Future<ImanJourneyResponseDto> getImanJourney(
    String userId, {
    DateTime? date,
  }) async {
    return ImanJourneyResponseDto(
      journeyDate: '2026-06-02',
      todayFocus: 'Stay mindful today',
      continueYesterdayTopic: 'Patience',
      progress: const ImanJourneyProgressDto(prayer: 3, quran: 1, dhikr: 20),
      personalDuaList: List<ImanDuaItemDto>.from(_duas),
      familyReminder: const ImanJourneyFamilyReminderDto(
        consentGranted: false,
        reminderText: null,
        notifyFamily: false,
      ),
      askSakinaTodayContext: 'Respect family boundaries',
      tomorrowFollowUp: 'Check in after Fajr',
      privacySettings: privacy,
      religiousReminder: const ImanJourneyReligiousReminderDto(
        text: null,
        confidenceScore: 0.0,
        evidenceBundle: [],
        safeFallback: ImanJourneySafeFallbackDto(
          reason: 'insufficient_evidence',
          message: 'Verified evidence is not available right now.',
        ),
      ),
    );
  }

  @override
  Future<ImanJourneyPrivacySettingsDto> updateImanJourneyPrivacy(
    String userId,
    ImanJourneyPrivacySettingsDto request,
  ) async {
    privacy = request;
    return privacy;
  }

  @override
  Future<ImanDuaItemDto> addDuaItem(String userId, String duaText) async {
    final item = ImanDuaItemDto(
      id: 'dua-${_duas.length + 1}',
      duaText: duaText,
      isAnswered: false,
    );
    _duas.insert(0, item);
    return item;
  }

  @override
  void close() {}
}

void main() {
  testWidgets('renders fallback and privacy switches', (tester) async {
    final api = _FakeApiService();
    await tester.pumpWidget(
      MaterialApp(
        home: ImanJourneyScreen(
          api: api,
          userId: '00000000-0000-0000-0000-000000000001',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today\'s Iman Focus'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Safe fallback if evidence is missing'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Verified evidence is not available'), findsOneWidget);
    expect(find.text('Save Privacy'), findsOneWidget);
  });

  testWidgets('updates privacy and adds dua item', (tester) async {
    final api = _FakeApiService();
    await tester.pumpWidget(
      MaterialApp(
        home: ImanJourneyScreen(
          api: api,
          userId: '00000000-0000-0000-0000-000000000001',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Notification/privacy settings'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Privacy'));
    await tester.pumpAndSettle();
    expect(api.privacy.remindersEnabled, isFalse);

    await tester.fling(find.byType(ListView).first, const Offset(0, 1200), 1200);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Personal Dua List'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).first, 'Grant me steadfastness');
    await tester.tap(find.text('Add Dua'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Grant me steadfastness'), findsOneWidget);
  });
}
