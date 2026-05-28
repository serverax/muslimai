import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/screens/module_read_only_state_screen.dart';
import 'package:sakina_frontend/services/module_service.dart';

void main() {
  testWidgets('gated module blocks UI access', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleReadOnlyStateScreen<QuranOverviewDto>(
            title: 'Quran',
            load: () async => const ModuleResult(
              module: ModuleKey.quran,
              state: ModuleAccessState.subscriptionRequired,
              message: 'premium entitlement required',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
        find.textContaining('requires premium subscription'), findsOneWidget);
  });

  testWidgets('under-review content displays safe message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleReadOnlyStateScreen<QuranOverviewDto>(
            title: 'Quran',
            load: () async => const ModuleResult(
              module: ModuleKey.quran,
              state: ModuleAccessState.requiresReview,
              message: 'coming soon / under review',
              overview: QuranOverviewDto(
                module: ModuleKey.quran,
                safetyStatus: ModuleSafetyStatus.requiresReview,
                reviewStatus: ReviewStatus.scholarReviewRequired,
                message: 'coming soon / under review',
                rag: RagReadinessDto(
                  ragEnabled: false,
                  ragIndexReady: false,
                  verifiedSourceCount: 0,
                  lastIndexedAt: null,
                  reviewStatus: ReviewStatus.scholarReviewRequired,
                ),
                provenance: [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('consult a qualified scholar'), findsOneWidget);
  });

  testWidgets('scholar-review-required response displays warning',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleReadOnlyStateScreen<QuranOverviewDto>(
            title: 'Quran',
            load: () async => const ModuleResult(
              module: ModuleKey.quran,
              state: ModuleAccessState.requiresReview,
              message: 'under review',
              overview: QuranOverviewDto(
                module: ModuleKey.quran,
                safetyStatus: ModuleSafetyStatus.requiresReview,
                reviewStatus: ReviewStatus.scholarReviewRequired,
                message: 'under review',
                rag: RagReadinessDto(
                  ragEnabled: false,
                  ragIndexReady: false,
                  verifiedSourceCount: 0,
                  lastIndexedAt: null,
                  reviewStatus: ReviewStatus.scholarReviewRequired,
                ),
                provenance: [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('consult a qualified scholar'), findsOneWidget);
  });

  testWidgets('verified read-only response renders citation/source fields',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleReadOnlyStateScreen<QuranOverviewDto>(
            title: 'Quran',
            load: () async => const ModuleResult(
              module: ModuleKey.quran,
              state: ModuleAccessState.enabledReadOnly,
              message: 'verified read-only content available',
              overview: QuranOverviewDto(
                module: ModuleKey.quran,
                safetyStatus: ModuleSafetyStatus.enabledReadOnly,
                reviewStatus: ReviewStatus.verified,
                message: 'verified read-only content available',
                rag: RagReadinessDto(
                  ragEnabled: true,
                  ragIndexReady: true,
                  verifiedSourceCount: 1,
                  lastIndexedAt: '2026-05-28T10:00:00Z',
                  reviewStatus: ReviewStatus.verified,
                ),
                provenance: [
                  SourceProvenanceDto(
                    sourceType: 'tafsir',
                    sourceName: 'Verified Source',
                    sourceReference: '1:1',
                    reviewStatus: 'verified',
                    effectiveDate: '2026-05-28',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verified Source'), findsOneWidget);
    expect(find.textContaining('1:1'), findsOneWidget);
    expect(find.textContaining('review: verified'), findsOneWidget);
  });
}
