import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakina_frontend/services/module_service.dart';

class FakeModuleApiClient extends ModuleApiClient {
  FakeModuleApiClient() : super(baseUrl: 'http://test');

  int calls = 0;

  @override
  Future<QuranOverviewDto> fetchQuranOverview({required String tier}) async {
    calls += 1;
    return const QuranOverviewDto(
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
    );
  }

  @override
  Future<PrayerOverviewDto> fetchPrayerOverview({required String tier}) async {
    calls += 1;
    return const PrayerOverviewDto(
      module: ModuleKey.prayer,
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
    );
  }

  @override
  Future<KnowledgeOverviewDto> fetchKnowledgeOverview(
      {required String tier}) async {
    calls += 1;
    return const KnowledgeOverviewDto(
      module: ModuleKey.knowledge,
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
    );
  }

  @override
  Future<CommunityOverviewDto> fetchCommunityOverview(
      {required String tier}) async {
    calls += 1;
    return const CommunityOverviewDto(
      module: ModuleKey.community,
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
    );
  }
}

void main() {
  test('disabled modules do not call backend', () async {
    final fakeClient = FakeModuleApiClient();
    final service = ModuleService(
      apiClient: fakeClient,
      entitlementGate: EntitlementGate(tier: 'premium'),
      featureGate: const ModuleFeatureGate(
        quran: false,
        prayer: false,
        knowledge: false,
        community: false,
      ),
    );

    final q = await service.quran();
    final p = await service.prayer();
    final k = await service.knowledge();
    final c = await service.community();

    expect(q.state, ModuleAccessState.featureDisabled);
    expect(p.state, ModuleAccessState.featureDisabled);
    expect(k.state, ModuleAccessState.featureDisabled);
    expect(c.state, ModuleAccessState.featureDisabled);
    expect(fakeClient.calls, 0);
  });

  test('missing entitlement blocks access before backend call', () async {
    final fakeClient = FakeModuleApiClient();
    final service = ModuleService(
      apiClient: fakeClient,
      entitlementGate: EntitlementGate(tier: 'free'),
      featureGate: const ModuleFeatureGate(
        quran: true,
        prayer: true,
        knowledge: true,
        community: true,
      ),
    );

    final result = await service.quran();
    expect(result.state, ModuleAccessState.subscriptionRequired);
    expect(fakeClient.calls, 0);
  });

  test('enabled module calls correct endpoint', () async {
    late Uri captured;
    final mock = MockClient((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode({
          'module': 'quran',
          'safety_status': 'requires_review',
          'review_status': 'scholar_review_required',
          'message': 'coming soon / under review',
          'rag': {
            'rag_enabled': true,
            'rag_index_ready': true,
            'verified_source_count': 4,
            'last_indexed_at': '2026-05-28T10:00:00Z',
            'review_status': 'verified',
          },
          'entries': [],
        }),
        200,
      );
    });

    final client = ModuleApiClient(baseUrl: 'http://test/v1', client: mock);
    final service = ModuleService(
      apiClient: client,
      entitlementGate: EntitlementGate(tier: 'premium'),
      featureGate: const ModuleFeatureGate(
        quran: true,
        prayer: false,
        knowledge: false,
        community: false,
      ),
    );

    final result = await service.quran();
    expect(captured.toString(), 'http://test/v1/modules/quran/overview');
    expect(result.state, ModuleAccessState.requiresReview);
    expect(result.overview?.provenance, isEmpty);
    expect(result.overview?.rag.verifiedSourceCount, 4);
  });

  test('backend error format propagates via ApiException', () async {
    final mock = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'feature_disabled',
            'message': 'module is disabled by feature flag',
          }
        }),
        403,
      );
    });
    final client = ModuleApiClient(baseUrl: 'http://test/v1', client: mock);
    expect(
      () => client.fetchQuranOverview(tier: 'premium'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('[feature_disabled]'),
        ),
      ),
    );
  });

  test('quran dto parsing', () {
    final dto = QuranOverviewDto.fromJson({
      'module': 'quran',
      'safety_status': 'requires_review',
      'review_status': 'scholar_review_required',
      'message': 'under review',
      'rag': {
        'rag_enabled': false,
        'rag_index_ready': false,
        'verified_source_count': 0,
        'last_indexed_at': null,
        'review_status': 'scholar_review_required',
      },
      'entries': [
        {
          'source_type': 'tafsir',
          'source_name': 'Ibn Kathir',
          'source_reference': '1:1',
          'review_status': 'scholar_review_pending',
          'effective_date': '2026-06-01',
        }
      ],
    });
    expect(dto.safetyStatus, ModuleSafetyStatus.requiresReview);
    expect(dto.provenance.single.sourceName, 'Ibn Kathir');
  });

  test('prayer dto parsing', () {
    final dto = PrayerOverviewDto.fromJson({
      'module': 'prayer',
      'safety_status': 'requires_review',
      'review_status': 'scholar_review_required',
      'message': 'under review',
      'rag': {
        'rag_enabled': false,
        'rag_index_ready': false,
        'verified_source_count': 0,
        'last_indexed_at': null,
        'review_status': 'scholar_review_required',
      },
      'windows': [
        {
          'source_type': 'calculation',
          'source_name': 'MOONSighting',
          'source_reference': 'Riyadh',
          'review_status': 'ops_verified',
          'effective_date': null,
        }
      ],
    });
    expect(dto.provenance.single.sourceType, 'calculation');
  });

  test('knowledge dto parsing', () {
    final dto = KnowledgeOverviewDto.fromJson({
      'module': 'knowledge',
      'safety_status': 'requires_review',
      'review_status': 'scholar_review_required',
      'message': 'under review',
      'rag': {
        'rag_enabled': false,
        'rag_index_ready': false,
        'verified_source_count': 0,
        'last_indexed_at': null,
        'review_status': 'scholar_review_required',
      },
      'topics': [
        {
          'source_type': 'article',
          'source_name': 'Fiqh Manual',
          'source_reference': 'Chapter 2',
          'review_status': 'editor_review_pending',
          'effective_date': '2026-07-01',
        }
      ],
    });
    expect(dto.provenance.single.sourceReference, 'Chapter 2');
  });

  test('community dto parsing', () {
    final dto = CommunityOverviewDto.fromJson({
      'module': 'community',
      'safety_status': 'requires_review',
      'review_status': 'scholar_review_required',
      'message': 'under review',
      'rag': {
        'rag_enabled': false,
        'rag_index_ready': false,
        'verified_source_count': 0,
        'last_indexed_at': null,
        'review_status': 'scholar_review_required',
      },
      'channels': [
        {
          'source_type': 'policy',
          'source_name': 'Community Guidelines',
          'source_reference': 'v1',
          'review_status': 'moderation_review_pending',
          'effective_date': null,
        }
      ],
    });
    expect(dto.provenance.single.reviewStatus, 'moderation_review_pending');
  });

  test('dto parsing fails when provenance fields are missing', () {
    expect(
      () => QuranOverviewDto.fromJson({
        'module': 'quran',
        'safety_status': 'requires_review',
        'review_status': 'scholar_review_required',
        'message': 'under review',
        'rag': {
          'rag_enabled': false,
          'rag_index_ready': false,
          'verified_source_count': 0,
          'last_indexed_at': null,
          'review_status': 'scholar_review_required',
        },
        'entries': [
          {
            'source_type': 'tafsir',
            // source_name missing on purpose
            'source_reference': '1:1',
            'review_status': 'pending',
          }
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('no mock religious payloads in production tests', () async {
    final mock = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'module': 'quran',
          'safety_status': 'requires_review',
          'review_status': 'scholar_review_required',
          'message': 'coming soon / under review',
          'rag': {
            'rag_enabled': false,
            'rag_index_ready': false,
            'verified_source_count': 0,
            'last_indexed_at': null,
            'review_status': 'scholar_review_required',
          },
          'entries': [],
        }),
        200,
      );
    });
    final client = ModuleApiClient(baseUrl: 'http://test/v1', client: mock);
    final dto = await client.fetchQuranOverview(tier: 'premium');
    expect(dto.provenance, isEmpty);
    expect(dto.message, contains('under review'));
  });
}
