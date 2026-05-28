import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/feature_flags.dart';
import '../config/api_config.dart';
import 'api_service.dart';

enum ModuleKey { quran, prayer, knowledge, community }

enum ModuleSafetyStatus {
  disabled,
  gated,
  enabledReadOnly,
  requiresReview,
}

enum ReviewStatus {
  unverified,
  verified,
  scholarReviewRequired,
  rejected,
  disabled,
}

enum ModuleAccessState {
  featureDisabled,
  subscriptionRequired,
  enabledReadOnly,
  requiresReview,
}

class SourceProvenanceDto {
  const SourceProvenanceDto({
    required this.sourceType,
    required this.sourceName,
    required this.sourceReference,
    required this.reviewStatus,
    this.effectiveDate,
  });

  final String sourceType;
  final String sourceName;
  final String sourceReference;
  final String reviewStatus;
  final String? effectiveDate;

  factory SourceProvenanceDto.fromJson(Map<String, dynamic> json) {
    return SourceProvenanceDto(
      sourceType: _requiredField(json, 'source_type'),
      sourceName: _requiredField(json, 'source_name'),
      sourceReference: _requiredField(json, 'source_reference'),
      reviewStatus: _requiredField(json, 'review_status'),
      effectiveDate: json['effective_date'] as String?,
    );
  }
}

class ModuleOverviewDto {
  const ModuleOverviewDto({
    required this.module,
    required this.safetyStatus,
    required this.reviewStatus,
    required this.message,
    required this.rag,
    required this.provenance,
  });

  final ModuleKey module;
  final ModuleSafetyStatus safetyStatus;
  final ReviewStatus reviewStatus;
  final String message;
  final RagReadinessDto rag;
  final List<SourceProvenanceDto> provenance;
}

class RagReadinessDto {
  const RagReadinessDto({
    required this.ragEnabled,
    required this.ragIndexReady,
    required this.verifiedSourceCount,
    required this.lastIndexedAt,
    required this.reviewStatus,
  });

  final bool ragEnabled;
  final bool ragIndexReady;
  final int verifiedSourceCount;
  final String? lastIndexedAt;
  final ReviewStatus reviewStatus;

  factory RagReadinessDto.fromJson(Map<String, dynamic> json) {
    return RagReadinessDto(
      ragEnabled: json['rag_enabled'] as bool? ?? false,
      ragIndexReady: json['rag_index_ready'] as bool? ?? false,
      verifiedSourceCount:
          (json['verified_source_count'] as num?)?.toInt() ?? 0,
      lastIndexedAt: json['last_indexed_at'] as String?,
      reviewStatus: _reviewStatusFromJson(json['review_status']),
    );
  }
}

class QuranOverviewDto extends ModuleOverviewDto {
  const QuranOverviewDto({
    required super.module,
    required super.safetyStatus,
    required super.reviewStatus,
    required super.message,
    required super.rag,
    required super.provenance,
  });

  factory QuranOverviewDto.fromJson(Map<String, dynamic> json) {
    return QuranOverviewDto(
      module: ModuleKey.quran,
      safetyStatus: _safetyFromJson(json['safety_status']),
      reviewStatus: _reviewStatusFromJson(json['review_status']),
      message: json['message'] as String? ?? '',
      rag: RagReadinessDto.fromJson(
          (json['rag'] as Map<String, dynamic>? ?? const {})),
      provenance: (json['entries'] as List<dynamic>? ?? const [])
          .map((e) => SourceProvenanceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PrayerOverviewDto extends ModuleOverviewDto {
  const PrayerOverviewDto({
    required super.module,
    required super.safetyStatus,
    required super.reviewStatus,
    required super.message,
    required super.rag,
    required super.provenance,
  });

  factory PrayerOverviewDto.fromJson(Map<String, dynamic> json) {
    return PrayerOverviewDto(
      module: ModuleKey.prayer,
      safetyStatus: _safetyFromJson(json['safety_status']),
      reviewStatus: _reviewStatusFromJson(json['review_status']),
      message: json['message'] as String? ?? '',
      rag: RagReadinessDto.fromJson(
          (json['rag'] as Map<String, dynamic>? ?? const {})),
      provenance: (json['windows'] as List<dynamic>? ?? const [])
          .map((e) => SourceProvenanceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class KnowledgeOverviewDto extends ModuleOverviewDto {
  const KnowledgeOverviewDto({
    required super.module,
    required super.safetyStatus,
    required super.reviewStatus,
    required super.message,
    required super.rag,
    required super.provenance,
  });

  factory KnowledgeOverviewDto.fromJson(Map<String, dynamic> json) {
    return KnowledgeOverviewDto(
      module: ModuleKey.knowledge,
      safetyStatus: _safetyFromJson(json['safety_status']),
      reviewStatus: _reviewStatusFromJson(json['review_status']),
      message: json['message'] as String? ?? '',
      rag: RagReadinessDto.fromJson(
          (json['rag'] as Map<String, dynamic>? ?? const {})),
      provenance: (json['topics'] as List<dynamic>? ?? const [])
          .map((e) => SourceProvenanceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CommunityOverviewDto extends ModuleOverviewDto {
  const CommunityOverviewDto({
    required super.module,
    required super.safetyStatus,
    required super.reviewStatus,
    required super.message,
    required super.rag,
    required super.provenance,
  });

  factory CommunityOverviewDto.fromJson(Map<String, dynamic> json) {
    return CommunityOverviewDto(
      module: ModuleKey.community,
      safetyStatus: _safetyFromJson(json['safety_status']),
      reviewStatus: _reviewStatusFromJson(json['review_status']),
      message: json['message'] as String? ?? '',
      rag: RagReadinessDto.fromJson(
          (json['rag'] as Map<String, dynamic>? ?? const {})),
      provenance: (json['channels'] as List<dynamic>? ?? const [])
          .map((e) => SourceProvenanceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ModuleResult<T extends ModuleOverviewDto> {
  const ModuleResult({
    required this.module,
    required this.state,
    required this.message,
    this.overview,
  });

  final ModuleKey module;
  final ModuleAccessState state;
  final String message;
  final T? overview;
}

class ModuleFeatureGate {
  const ModuleFeatureGate({
    bool? quran,
    bool? prayer,
    bool? knowledge,
    bool? community,
  })  : quran = quran ?? FeatureFlags.quran,
        prayer = prayer ?? FeatureFlags.prayer,
        knowledge = knowledge ?? FeatureFlags.knowledge,
        community = community ?? FeatureFlags.community;

  final bool quran;
  final bool prayer;
  final bool knowledge;
  final bool community;

  bool isEnabled(ModuleKey key) {
    return switch (key) {
      ModuleKey.quran => quran,
      ModuleKey.prayer => prayer,
      ModuleKey.knowledge => knowledge,
      ModuleKey.community => community,
    };
  }
}

class EntitlementGate {
  EntitlementGate({String? tier})
      : _tier = (tier ??
                const String.fromEnvironment(
                  'SAKINA_SUBSCRIPTION_TIER',
                  defaultValue: 'free',
                ))
            .toLowerCase();

  final String _tier;

  bool canAccess(ModuleKey module) {
    switch (module) {
      case ModuleKey.quran:
      case ModuleKey.prayer:
      case ModuleKey.knowledge:
      case ModuleKey.community:
        return _tier == 'premium' || _tier == 'pro' || _tier == 'founding';
    }
  }

  String get tierHeaderValue => _tier;
}

class ModuleApiClient {
  ModuleApiClient({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<QuranOverviewDto> fetchQuranOverview({required String tier}) async {
    final response = await _get('/modules/quran/overview', tier: tier);
    return QuranOverviewDto.fromJson(response);
  }

  Future<PrayerOverviewDto> fetchPrayerOverview({required String tier}) async {
    final response = await _get('/modules/prayer/overview', tier: tier);
    return PrayerOverviewDto.fromJson(response);
  }

  Future<KnowledgeOverviewDto> fetchKnowledgeOverview(
      {required String tier}) async {
    final response = await _get('/modules/knowledge/overview', tier: tier);
    return KnowledgeOverviewDto.fromJson(response);
  }

  Future<CommunityOverviewDto> fetchCommunityOverview(
      {required String tier}) async {
    final response = await _get('/modules/community/overview', tier: tier);
    return CommunityOverviewDto.fromJson(response);
  }

  Future<Map<String, dynamic>> _get(String path, {required String tier}) async {
    final uri = Uri.parse('${_endpointBase()}$path');
    final res = await _client.get(uri, headers: {
      'x-sakina-subscription-tier': tier,
    });
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(_errorMessage('module overview failed', res));
  }

  String _endpointBase() {
    if (_baseUrl.endsWith('/v1')) return _baseUrl;
    return '$_baseUrl/v1';
  }

  String _errorMessage(String fallback, http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final code = error['code']?.toString();
        final message = error['message']?.toString();
        if (code != null && message != null) {
          return '$fallback [$code]: $message (HTTP ${response.statusCode})';
        }
      }
    } catch (_) {}
    return '$fallback: HTTP ${response.statusCode}';
  }

  void close() => _client.close();
}

class ModuleService {
  ModuleService({
    required ModuleApiClient apiClient,
    required EntitlementGate entitlementGate,
    ModuleFeatureGate? featureGate,
  })  : _apiClient = apiClient,
        _entitlementGate = entitlementGate,
        _featureGate = featureGate ?? const ModuleFeatureGate();

  final ModuleApiClient _apiClient;
  final EntitlementGate _entitlementGate;
  final ModuleFeatureGate _featureGate;

  Future<ModuleResult<QuranOverviewDto>> quran() async {
    if (!_featureGate.isEnabled(ModuleKey.quran)) {
      return const ModuleResult(
        module: ModuleKey.quran,
        state: ModuleAccessState.featureDisabled,
        message: 'coming soon / under review',
      );
    }
    if (!_entitlementGate.canAccess(ModuleKey.quran)) {
      return const ModuleResult(
        module: ModuleKey.quran,
        state: ModuleAccessState.subscriptionRequired,
        message: 'premium entitlement required',
      );
    }
    final overview = await _apiClient.fetchQuranOverview(
        tier: _entitlementGate.tierHeaderValue);
    return ModuleResult(
      module: ModuleKey.quran,
      state: _mapSafety(overview.safetyStatus),
      message: overview.message,
      overview: overview,
    );
  }

  Future<ModuleResult<PrayerOverviewDto>> prayer() async {
    if (!_featureGate.isEnabled(ModuleKey.prayer)) {
      return const ModuleResult(
        module: ModuleKey.prayer,
        state: ModuleAccessState.featureDisabled,
        message: 'coming soon / under review',
      );
    }
    if (!_entitlementGate.canAccess(ModuleKey.prayer)) {
      return const ModuleResult(
        module: ModuleKey.prayer,
        state: ModuleAccessState.subscriptionRequired,
        message: 'premium entitlement required',
      );
    }
    final overview = await _apiClient.fetchPrayerOverview(
        tier: _entitlementGate.tierHeaderValue);
    return ModuleResult(
      module: ModuleKey.prayer,
      state: _mapSafety(overview.safetyStatus),
      message: overview.message,
      overview: overview,
    );
  }

  Future<ModuleResult<KnowledgeOverviewDto>> knowledge() async {
    if (!_featureGate.isEnabled(ModuleKey.knowledge)) {
      return const ModuleResult(
        module: ModuleKey.knowledge,
        state: ModuleAccessState.featureDisabled,
        message: 'coming soon / under review',
      );
    }
    if (!_entitlementGate.canAccess(ModuleKey.knowledge)) {
      return const ModuleResult(
        module: ModuleKey.knowledge,
        state: ModuleAccessState.subscriptionRequired,
        message: 'premium entitlement required',
      );
    }
    final overview = await _apiClient.fetchKnowledgeOverview(
      tier: _entitlementGate.tierHeaderValue,
    );
    return ModuleResult(
      module: ModuleKey.knowledge,
      state: _mapSafety(overview.safetyStatus),
      message: overview.message,
      overview: overview,
    );
  }

  Future<ModuleResult<CommunityOverviewDto>> community() async {
    if (!_featureGate.isEnabled(ModuleKey.community)) {
      return const ModuleResult(
        module: ModuleKey.community,
        state: ModuleAccessState.featureDisabled,
        message: 'coming soon / under review',
      );
    }
    if (!_entitlementGate.canAccess(ModuleKey.community)) {
      return const ModuleResult(
        module: ModuleKey.community,
        state: ModuleAccessState.subscriptionRequired,
        message: 'premium entitlement required',
      );
    }
    final overview = await _apiClient.fetchCommunityOverview(
      tier: _entitlementGate.tierHeaderValue,
    );
    return ModuleResult(
      module: ModuleKey.community,
      state: _mapSafety(overview.safetyStatus),
      message: overview.message,
      overview: overview,
    );
  }

  ModuleAccessState _mapSafety(ModuleSafetyStatus safety) {
    return switch (safety) {
      ModuleSafetyStatus.disabled => ModuleAccessState.featureDisabled,
      ModuleSafetyStatus.gated => ModuleAccessState.subscriptionRequired,
      ModuleSafetyStatus.enabledReadOnly => ModuleAccessState.enabledReadOnly,
      ModuleSafetyStatus.requiresReview => ModuleAccessState.requiresReview,
    };
  }

  void close() => _apiClient.close();
}

ModuleSafetyStatus _safetyFromJson(Object? value) {
  final v = value?.toString() ?? '';
  return switch (v) {
    'disabled' => ModuleSafetyStatus.disabled,
    'gated' => ModuleSafetyStatus.gated,
    'enabled_read_only' => ModuleSafetyStatus.enabledReadOnly,
    'requires_review' => ModuleSafetyStatus.requiresReview,
    _ => ModuleSafetyStatus.requiresReview,
  };
}

String _requiredField(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Missing required provenance field: $key');
}

ReviewStatus _reviewStatusFromJson(Object? value) {
  final v = value?.toString() ?? '';
  return switch (v) {
    'unverified' => ReviewStatus.unverified,
    'verified' => ReviewStatus.verified,
    'scholar_review_required' => ReviewStatus.scholarReviewRequired,
    'rejected' => ReviewStatus.rejected,
    'disabled' => ReviewStatus.disabled,
    _ => ReviewStatus.scholarReviewRequired,
  };
}
