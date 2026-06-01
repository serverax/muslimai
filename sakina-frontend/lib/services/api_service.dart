import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Step 12 (Phase 3): typed client for the Sakina backend (uses `http`).
class ApiService {
  final String baseUrl;
  final http.Client _client;
  final String? _apiToken;

  ApiService({
    required this.baseUrl,
    http.Client? client,
    String? apiToken,
  })  : _client = client ?? http.Client(),
        _apiToken = apiToken ??
            (() {
              const token = String.fromEnvironment('SAKINA_API_TOKEN');
              return token.isEmpty ? null : token;
            })();

  Future<RagResponse> query(
    String message, {
    String? madhhab,
    String? userId,
  }) async {
    final requestUserId = userId ?? '00000000-0000-0000-0000-000000000000';
    final res = await _withRetry(
      () => _client
          .post(
            Uri.parse(_endpoint('/rag/query')),
            headers: _headers(userId: requestUserId),
            body: jsonEncode({
              'query': message,
              'user_id': requestUserId,
              'madhhab_filter': madhhab ?? '',
            }),
          )
          .timeout(const Duration(seconds: 30)),
    );
    if (res.statusCode == 200) {
      return RagResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('rag/query failed', res);
  }

  Future<ClassifyResponse> classify(String text, {String? userId}) async {
    final res = await _withRetry(
      () => _client
          .post(
            Uri.parse(_endpoint('/classify')),
            headers: _headers(userId: userId),
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 10)),
    );
    if (res.statusCode == 200) {
      return ClassifyResponse.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('classify failed', res);
  }

  /// Server's public key (base64/string) for encrypted backup.
  Future<String> getPublicKey() async {
    final res = await _withRetry(
      () => _client
          .get(Uri.parse(_endpoint('/users/pubkey')), headers: _headers())
          .timeout(const Duration(seconds: 10)),
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded['pub_key'] as String? ?? '';
    }
    throw _apiException('getPublicKey failed', res);
  }

  Future<void> joinWaitlist({
    required String name,
    required String email,
    String? preferredLanguage,
    String? platform,
    String? message,
  }) async {
    final res = await _withRetry(
      () => _client
          .post(
            Uri.parse(_endpoint('/waitlist')),
            headers: _headers(),
            body: jsonEncode({
              'name': name,
              'email': email,
              if (preferredLanguage != null)
                'preferred_language': preferredLanguage,
              if (platform != null) 'platform': platform,
              if (message != null) 'message': message,
            }),
          )
          .timeout(const Duration(seconds: 10)),
    );
    if (res.statusCode != 200) {
      throw _apiException('waitlist failed', res);
    }
  }

  Future<void> uploadBackup(
    String encrypted, {
    required String userId,
  }) async {
    final res = await _withRetry(
      () => _client
          .post(
            Uri.parse(_endpoint('/sync/backup/$userId')),
            headers: _headers(userId: userId),
            body: jsonEncode({'data': encrypted}),
          )
          .timeout(const Duration(seconds: 60)),
    );
    if (res.statusCode != 200) {
      throw _apiException('uploadBackup failed', res);
    }
  }

  Future<String> downloadBackup({required String userId}) async {
    final res = await _withRetry(
      () => _client
          .get(
            Uri.parse(_endpoint('/sync/backup/$userId')),
            headers: _headers(userId: userId),
          )
          .timeout(const Duration(seconds: 30)),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map<String, dynamic>)['data'] as String;
    }
    throw _apiException('downloadBackup failed', res);
  }

  Future<RegisterUserResponse> registerUser(RegisterUserRequest request) async {
    final res = await _post('/auth/register', request.toJson());
    if (res.statusCode == 201) {
      return RegisterUserResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('register failed', res);
  }

  Future<SessionResponse> createSession(CreateSessionRequest request) async {
    final res = await _post('/auth/sessions', request.toJson());
    if (res.statusCode == 201) {
      return SessionResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('create session failed', res);
  }

  Future<ProfileResponse> upsertProfile(
    String userId,
    UpsertProfileRequest request,
  ) async {
    final res = await _put('/profiles/$userId', request.toJson(), userId: userId);
    if (res.statusCode == 200) {
      return ProfileResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('upsert profile failed', res);
  }

  Future<FamilyProfileResponse> createFamilyProfile(
    String userId,
    CreateFamilyProfileRequest request,
  ) async {
    final res =
        await _post('/profiles/$userId/family', request.toJson(), userId: userId);
    if (res.statusCode == 201) {
      return FamilyProfileResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('create family profile failed', res);
  }

  Future<SubscriptionResponse> activateSubscription(
    String userId,
    ActivateSubscriptionRequest request,
  ) async {
    final res = await _post(
      '/subscriptions/$userId/activate',
      request.toJson(),
      userId: userId,
    );
    if (res.statusCode == 201) {
      return SubscriptionResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('activate subscription failed', res);
  }

  Future<List<String>> listEntitlements(String userId) async {
    final res = await _get('/subscriptions/$userId/entitlements', userId: userId);
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['entitlements'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
    }
    throw _apiException('list entitlements failed', res);
  }

  Future<List<IslamicSourceDto>> getIslamicSources({
    String? language,
    String? source,
  }) async {
    final query = <String, String>{};
    if (language != null && language.isNotEmpty) query['language'] = language;
    if (source != null && source.isNotEmpty) query['source'] = source;
    final uri = Uri.parse(_endpoint('/islamic/sources')).replace(queryParameters: query);
    final res = await _withRetry(
      () => _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 30)),
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return (decoded['sources'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(IslamicSourceDto.fromJson)
          .toList();
    }
    throw _apiException('list islamic sources failed', res);
  }

  Future<List<IslamicDocumentDto>> getIslamicDocuments({
    String? language,
    String? source,
  }) async {
    final query = <String, String>{};
    if (language != null && language.isNotEmpty) query['language'] = language;
    if (source != null && source.isNotEmpty) query['source'] = source;
    final uri = Uri.parse(_endpoint('/islamic/documents')).replace(queryParameters: query);
    final res = await _withRetry(
      () => _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 30)),
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return (decoded['documents'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(IslamicDocumentDto.fromJson)
          .toList();
    }
    throw _apiException('list islamic documents failed', res);
  }

  Future<List<IslamicChunkDto>> getIslamicChunks(String documentId) async {
    final res = await _get('/islamic/documents/$documentId/chunks');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return (decoded['chunks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(IslamicChunkDto.fromJson)
          .toList();
    }
    throw _apiException('list islamic chunks failed', res);
  }

  Future<List<IslamicSearchResultDto>> searchIslamic({
    required String query,
    required String language,
    String? source,
  }) async {
    final params = <String, String>{'q': query, 'language': language};
    if (source != null && source.isNotEmpty) {
      params['source'] = source;
    }
    final uri =
        Uri.parse(_endpoint('/islamic/search')).replace(queryParameters: params);
    final res = await _withRetry(
      () => _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 30)),
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return (decoded['results'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(IslamicSearchResultDto.fromJson)
          .toList();
    }
    throw _apiException('islamic search failed', res);
  }

  Future<IslamicAskResponseDto> askIslamic({
    required String question,
    required String language,
    String? source,
  }) async {
    final body = <String, dynamic>{
      'question': question,
      'language': language,
      if (source != null && source.isNotEmpty) 'source': source,
    };
    final res = await _post('/islamic/ask', body);
    if (res.statusCode == 200) {
      return IslamicAskResponseDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('islamic ask failed', res);
  }

  Future<CreateConversationResponse> createConversation({
    required String userId,
    required String title,
  }) async {
    final res = await _post(
      '/chat/conversations',
      {
        'user_id': userId,
        'title': title,
      },
      userId: userId,
    );
    if (res.statusCode == 200) {
      return CreateConversationResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('create conversation failed', res);
  }

  Future<AddMessageResponse> addConversationMessage({
    required String userId,
    required String conversationId,
    required String content,
  }) async {
    final res = await _post(
      '/chat/conversations/$conversationId/messages',
      {'content': content},
      userId: userId,
    );
    if (res.statusCode == 200) {
      return AddMessageResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('add message failed', res);
  }

  Future<void> sendChatFeedback({
    required String messageId,
    required String feedbackType,
    int? feedbackScore,
    String? comment,
  }) async {
    final res = await _post(
      '/chat/messages/$messageId/feedback',
      {
        'feedback_type': feedbackType,
        if (feedbackScore != null) 'feedback_score': feedbackScore,
        if (comment != null) 'feedback_comment': comment,
      },
    );
    if (res.statusCode != 201) {
      throw _apiException('send feedback failed', res);
    }
  }

  Future<void> reportMessage({
    required String messageId,
    required String reason,
    String? details,
  }) async {
    final res = await _post(
      '/chat/messages/$messageId/report',
      {
        'report_reason': reason,
        if (details != null) 'report_details': details,
      },
    );
    if (res.statusCode != 201) {
      throw _apiException('report message failed', res);
    }
  }

  Future<String> createNotificationTemplate({
    required String templateKey,
    required String subjectTemplate,
    required String bodyTemplate,
    String channel = 'in_app',
  }) async {
    final res = await _post(
      '/notifications/templates',
      {
        'template_key': templateKey,
        'channel': channel,
        'subject_template': subjectTemplate,
        'body_template': bodyTemplate,
        'locale': 'en-US',
      },
    );
    if (res.statusCode == 201) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['id']?.toString() ?? '';
    }
    throw _apiException('create notification template failed', res);
  }

  Future<void> sendNotification({
    required String userId,
    required String templateId,
    required String title,
    required String body,
  }) async {
    final res = await _post(
      '/notifications/send',
      {
        'user_id': userId,
        'template_id': templateId,
        'channel': 'in_app',
        'title': title,
        'body': body,
        'payload': const <String, dynamic>{},
      },
      userId: userId,
    );
    if (res.statusCode != 201) {
      throw _apiException('send notification failed', res);
    }
  }

  Future<void> upsertDeviceToken({
    required String userId,
    required String platform,
    required String tokenHash,
    String appVersion = '1.0.0',
  }) async {
    final res = await _post(
      '/notifications/device-tokens',
      {
        'user_id': userId,
        'platform': platform,
        'token_hash': tokenHash,
        'app_version': appVersion,
      },
      userId: userId,
    );
    if (res.statusCode != 201) {
      throw _apiException('upsert device token failed', res);
    }
  }

  Future<CreateSupportTicketResponse> createSupportTicket({
    required String userId,
    required String subject,
    required String messageBody,
    String priority = 'normal',
    String category = 'account',
  }) async {
    final res = await _post(
      '/support/tickets',
      {
        'user_id': userId,
        'priority': priority,
        'category': category,
        'subject': subject,
        'message_body': messageBody,
      },
      userId: userId,
    );
    if (res.statusCode == 201) {
      return CreateSupportTicketResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('create support ticket failed', res);
  }

  Future<void> appendSupportMessage({
    required String ticketId,
    required String messageBody,
  }) async {
    final res = await _post(
      '/support/tickets/$ticketId/messages',
      {
        'sender_type': 'user',
        'sender_user_id': null,
        'message_body': messageBody,
      },
    );
    if (res.statusCode != 201) {
      throw _apiException('append support message failed', res);
    }
  }

  Future<SupportTicketResponse> getSupportTicket(String ticketId) async {
    final res = await _get('/support/tickets/$ticketId');
    if (res.statusCode == 200) {
      return SupportTicketResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('get support ticket failed', res);
  }

  Future<ImanJourneyResponseDto> getImanJourney(
    String userId, {
    DateTime? date,
  }) async {
    final query = <String, String>{};
    if (date != null) {
      query['date'] = date.toIso8601String().split('T').first;
    }
    final uri = Uri.parse(_endpoint('/iman-journey/$userId'))
        .replace(queryParameters: query.isEmpty ? null : query);
    final res = await _withRetry(
      () => _client
          .get(uri, headers: _headers(userId: userId))
          .timeout(const Duration(seconds: 30)),
    );
    if (res.statusCode == 200) {
      return ImanJourneyResponseDto.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('get iman journey failed', res);
  }

  Future<ImanJourneyResponseDto> upsertImanJourney(
    String userId,
    UpsertImanJourneyRequestDto request,
  ) async {
    final res = await _put(
      '/iman-journey/$userId',
      request.toJson(),
      userId: userId,
    );
    if (res.statusCode == 200) {
      return ImanJourneyResponseDto.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('upsert iman journey failed', res);
  }

  Future<ImanJourneyPrivacySettingsDto> getImanJourneyPrivacy(
    String userId,
  ) async {
    final res = await _get('/iman-journey/$userId/privacy', userId: userId);
    if (res.statusCode == 200) {
      return ImanJourneyPrivacySettingsDto.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('get iman journey privacy failed', res);
  }

  Future<ImanJourneyPrivacySettingsDto> updateImanJourneyPrivacy(
    String userId,
    ImanJourneyPrivacySettingsDto request,
  ) async {
    final res = await _put(
      '/iman-journey/$userId/privacy',
      request.toJson(),
      userId: userId,
    );
    if (res.statusCode == 200) {
      return ImanJourneyPrivacySettingsDto.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('update iman journey privacy failed', res);
  }

  Future<List<ImanDuaItemDto>> getDuaList(String userId) async {
    final res = await _get('/dua-list/$userId', userId: userId);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return (decoded['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ImanDuaItemDto.fromJson)
          .toList();
    }
    throw _apiException('get dua list failed', res);
  }

  Future<ImanDuaItemDto> addDuaItem(String userId, String duaText) async {
    final res = await _post(
      '/dua-list/$userId',
      {'dua_text': duaText},
      userId: userId,
    );
    if (res.statusCode == 201) {
      return ImanDuaItemDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('add dua item failed', res);
  }

  void close() => _client.close();

  Map<String, String> _headers({String? userId}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _apiToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (userId != null && userId.isNotEmpty) {
      headers['x-sakina-user-id'] = userId;
    }
    return headers;
  }

  String _endpoint(String path) {
    if (baseUrl.endsWith('/v1')) {
      return '$baseUrl$path';
    }
    return '$baseUrl/v1$path';
  }

  Future<http.Response> _withRetry(Future<http.Response> Function() run) async {
    Object? lastError;
    for (var attempt = 0; attempt < ApiConfig.retryAttempts; attempt++) {
      try {
        final response = await run();
        if (response.statusCode >= 500 &&
            attempt < ApiConfig.retryAttempts - 1) {
          await Future<void>.delayed(
            ApiConfig.retryDelay * (attempt + 1),
          );
          continue;
        }
        return response;
      } catch (error) {
        lastError = error;
        if (attempt < ApiConfig.retryAttempts - 1) {
          await Future<void>.delayed(
            ApiConfig.retryDelay * (attempt + 1),
          );
          continue;
        }
      }
    }
    throw ApiException('request failed after retries: $lastError');
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String? userId,
  }) {
    return _withRetry(
      () => _client
          .post(
            Uri.parse(_endpoint(path)),
            headers: _headers(userId: userId),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30)),
    );
  }

  Future<http.Response> _put(
    String path,
    Map<String, dynamic> body, {
    String? userId,
  }) {
    return _withRetry(
      () => _client
          .put(
            Uri.parse(_endpoint(path)),
            headers: _headers(userId: userId),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30)),
    );
  }

  Future<http.Response> _get(String path, {String? userId}) {
    return _withRetry(
      () => _client
          .get(Uri.parse(_endpoint(path)), headers: _headers(userId: userId))
          .timeout(const Duration(seconds: 30)),
    );
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
        if (message != null) {
          return '$fallback: $message (HTTP ${response.statusCode})';
        }
      }
      if (error is String) {
        return '$fallback: $error (HTTP ${response.statusCode})';
      }
    } catch (_) {}
    return '$fallback: HTTP ${response.statusCode}';
  }

  ApiException _apiException(String fallback, http.Response response) {
    String? code;
    String? message;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        code = error['code']?.toString();
        message = error['message']?.toString();
      } else if (error is String) {
        message = error;
      }
    } catch (_) {}
    return ApiException(
      _errorMessage(fallback, response),
      statusCode: response.statusCode,
      errorCode: code,
      backendMessage: message,
    );
  }
}

class RagResponse {
  final String answer;
  final List<Citation> sources;
  final double confidence;
  final bool guardrailTriggered;
  final int processingTimeMs;

  RagResponse({
    required this.answer,
    required this.sources,
    required this.confidence,
    required this.guardrailTriggered,
    required this.processingTimeMs,
  });

  factory RagResponse.fromJson(Map<String, dynamic> json) => RagResponse(
        answer: json['answer'] as String? ?? '',
        sources: (json['sources'] as List<dynamic>?)
                ?.map((s) => Citation.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        guardrailTriggered: json['guardrail_triggered'] as bool? ?? false,
        processingTimeMs: (json['processing_time_ms'] as num?)?.toInt() ?? 0,
      );
}

class ClassifyResponse {
  final String intent;
  final double confidence;
  final String routingDecision;

  ClassifyResponse({
    required this.intent,
    required this.confidence,
    required this.routingDecision,
  });

  factory ClassifyResponse.fromJson(Map<String, dynamic> json) =>
      ClassifyResponse(
        intent: json['intent'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        routingDecision: json['routing_decision'] as String? ?? '',
      );
}

class Citation {
  final String id;
  final String title;
  final String author;
  final String? chapter;
  final String? authenticityGrade;

  Citation({
    required this.id,
    required this.title,
    required this.author,
    this.chapter,
    this.authenticityGrade,
  });

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        chapter: json['chapter'] as String?,
        authenticityGrade: json['authenticity_grade'] as String?,
      );

  bool get isVerifiedShape =>
      id.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      (chapter?.trim().isNotEmpty ?? false) &&
      (authenticityGrade?.trim().isNotEmpty ?? false);
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final String? backendMessage;
  ApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.backendMessage,
  });

  @override
  String toString() => 'ApiException: $message';
}

class IslamicSourceDto {
  final String id;
  final String sourceKey;
  final String sourceName;
  final String sourceType;
  final String language;
  final String? licenseName;

  IslamicSourceDto({
    required this.id,
    required this.sourceKey,
    required this.sourceName,
    required this.sourceType,
    required this.language,
    this.licenseName,
  });

  factory IslamicSourceDto.fromJson(Map<String, dynamic> json) => IslamicSourceDto(
        id: json['id']?.toString() ?? '',
        sourceKey: json['source_key']?.toString() ?? '',
        sourceName: json['source_name']?.toString() ?? '',
        sourceType: json['source_type']?.toString() ?? '',
        language: json['language']?.toString() ?? '',
        licenseName: json['license_name']?.toString(),
      );
}

class IslamicDocumentDto {
  final String id;
  final String sourceId;
  final String documentKey;
  final String title;
  final String language;
  final String sourceType;

  IslamicDocumentDto({
    required this.id,
    required this.sourceId,
    required this.documentKey,
    required this.title,
    required this.language,
    required this.sourceType,
  });

  factory IslamicDocumentDto.fromJson(Map<String, dynamic> json) =>
      IslamicDocumentDto(
        id: json['id']?.toString() ?? '',
        sourceId: json['source_id']?.toString() ?? '',
        documentKey: json['document_key']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        language: json['language']?.toString() ?? '',
        sourceType: json['source_type']?.toString() ?? '',
      );
}

class IslamicChunkDto {
  final String id;
  final String documentId;
  final int chunkIndex;
  final String chunkText;
  final String citationLabel;

  IslamicChunkDto({
    required this.id,
    required this.documentId,
    required this.chunkIndex,
    required this.chunkText,
    required this.citationLabel,
  });

  factory IslamicChunkDto.fromJson(Map<String, dynamic> json) => IslamicChunkDto(
        id: json['id']?.toString() ?? '',
        documentId: json['document_id']?.toString() ?? '',
        chunkIndex: (json['chunk_index'] as num?)?.toInt() ?? 0,
        chunkText: json['chunk_text']?.toString() ?? '',
        citationLabel: json['citation_label']?.toString() ?? '',
      );
}

class IslamicSearchResultDto {
  final String chunkId;
  final String sourceName;
  final String documentTitle;
  final String chunkText;
  final String citationLabel;
  final String language;

  IslamicSearchResultDto({
    required this.chunkId,
    required this.sourceName,
    required this.documentTitle,
    required this.chunkText,
    required this.citationLabel,
    required this.language,
  });

  factory IslamicSearchResultDto.fromJson(Map<String, dynamic> json) =>
      IslamicSearchResultDto(
        chunkId: json['chunk_id']?.toString() ?? '',
        sourceName: json['source_name']?.toString() ?? '',
        documentTitle: json['document_title']?.toString() ?? '',
        chunkText: json['chunk_text']?.toString() ?? '',
        citationLabel: json['citation_label']?.toString() ?? '',
        language: json['language']?.toString() ?? '',
      );
}

class IslamicAskResponseDto {
  final String language;
  final String answer;
  final bool fallbackUsed;
  final bool fatwaSensitive;
  final List<Citation> citations;

  IslamicAskResponseDto({
    required this.language,
    required this.answer,
    required this.fallbackUsed,
    required this.fatwaSensitive,
    required this.citations,
  });

  factory IslamicAskResponseDto.fromJson(Map<String, dynamic> json) =>
      IslamicAskResponseDto(
        language: json['language']?.toString() ?? 'en',
        answer: json['answer']?.toString() ?? '',
        fallbackUsed: json['fallback_used'] as bool? ?? false,
        fatwaSensitive: json['fatwa_sensitive'] as bool? ?? false,
        citations: (json['citations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Citation.fromJson)
            .toList(),
      );
}

class RegisterUserRequest {
  final String email;
  final String provider;
  final String providerUserId;
  final String? pubKey;

  RegisterUserRequest({
    required this.email,
    required this.provider,
    required this.providerUserId,
    this.pubKey,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'provider': provider,
        'provider_user_id': providerUserId,
        'pub_key': pubKey,
        'provider_email': null,
        'email_verified_at': null,
        'metadata': const <String, dynamic>{},
      };
}

class RegisterUserResponse {
  final String userId;

  RegisterUserResponse({required this.userId});

  factory RegisterUserResponse.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id']?.toString() ?? '';
    if (userId.isEmpty) {
      throw const FormatException('missing user_id in register response');
    }
    return RegisterUserResponse(userId: userId);
  }
}

class CreateSessionRequest {
  final String userId;
  final String sessionTokenHash;
  final String refreshTokenHash;
  final String expiresAt;
  final String refreshExpiresAt;
  final String ipAddress;
  final String userAgent;

  CreateSessionRequest({
    required this.userId,
    required this.sessionTokenHash,
    required this.refreshTokenHash,
    required this.expiresAt,
    required this.refreshExpiresAt,
    required this.ipAddress,
    required this.userAgent,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'session_token_hash': sessionTokenHash,
        'refresh_token_hash': refreshTokenHash,
        'expires_at': expiresAt,
        'refresh_expires_at': refreshExpiresAt,
        'ip_address': ipAddress,
        'user_agent': userAgent,
      };
}

class SessionResponse {
  final String sessionId;

  SessionResponse({required this.sessionId});

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    final id = json['session_id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const FormatException('missing session_id in session response');
    }
    return SessionResponse(sessionId: id);
  }
}

class UpsertProfileRequest {
  final String displayName;

  UpsertProfileRequest({required this.displayName});

  Map<String, dynamic> toJson() => {
        'full_name': displayName,
        'display_name': displayName,
        'timezone': 'UTC',
        'madhhab_preference': 'hanafi',
        'metadata': const <String, dynamic>{},
        'ui_language': 'en',
        'content_language': 'ar',
        'transliteration_enabled': true,
        'profile_visibility': 'private',
        'data_export_allowed': true,
        'analytics_opt_in': false,
        'text_scale': 1.0,
        'high_contrast_enabled': false,
        'reduced_motion_enabled': false,
        'screen_reader_optimized': false,
        'in_app_enabled': true,
        'email_enabled': false,
        'push_enabled': true,
      };
}

class ProfileResponse {
  final String userId;

  ProfileResponse({required this.userId});

  factory ProfileResponse.fromJson(Map<String, dynamic> json) => ProfileResponse(
        userId: json['user_id']?.toString() ?? '',
      );
}

class CreateFamilyProfileRequest {
  final String familyName;

  CreateFamilyProfileRequest({required this.familyName});

  Map<String, dynamic> toJson() => {
        'family_name': familyName,
        'household_size': 1,
        'location_country_code': 'US',
        'metadata': const <String, dynamic>{},
        'children': const [],
      };
}

class FamilyProfileResponse {
  final String familyProfileId;

  FamilyProfileResponse({required this.familyProfileId});

  factory FamilyProfileResponse.fromJson(Map<String, dynamic> json) =>
      FamilyProfileResponse(
        familyProfileId: json['family_profile_id']?.toString() ?? '',
      );
}

class ActivateSubscriptionRequest {
  final String providerKey;
  final String planKey;

  ActivateSubscriptionRequest({
    required this.providerKey,
    required this.planKey,
  });

  Map<String, dynamic> toJson() {
    final now = DateTime.now().toUtc();
    return {
      'provider_key': providerKey,
      'provider_display_name': 'Stripe',
      'provider_customer_ref': 'cust-$planKey',
      'plan_key': planKey,
      'plan_name': 'Premium',
      'billing_interval': 'monthly',
      'provider_subscription_ref': 'sub-$planKey',
      'provider_invoice_ref': 'inv-$planKey',
      'provider_transaction_ref': 'txn-$planKey',
      'currency_code': 'USD',
      'amount_minor': 1999,
      'current_period_start': now.toIso8601String(),
      'current_period_end': now.add(const Duration(days: 30)).toIso8601String(),
      'entitlement_keys': const ['chat_premium', 'rag_verified'],
    };
  }
}

class SubscriptionResponse {
  final String subscriptionId;

  SubscriptionResponse({required this.subscriptionId});

  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) =>
      SubscriptionResponse(
        subscriptionId: json['subscription_id']?.toString() ?? '',
      );
}

class CreateConversationResponse {
  final String id;
  final String title;

  CreateConversationResponse({required this.id, required this.title});

  factory CreateConversationResponse.fromJson(Map<String, dynamic> json) =>
      CreateConversationResponse(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
      );
}

class AddMessageResponse {
  final String conversationId;
  final String userMessageId;

  AddMessageResponse({
    required this.conversationId,
    required this.userMessageId,
  });

  factory AddMessageResponse.fromJson(Map<String, dynamic> json) {
    final conversationId = json['conversation_id']?.toString() ?? '';
    final userMessageId = json['user_message_id']?.toString() ?? '';
    if (conversationId.isEmpty || userMessageId.isEmpty) {
      throw const FormatException('message response missing identifiers');
    }
    return AddMessageResponse(
      conversationId: conversationId,
      userMessageId: userMessageId,
    );
  }
}

class CreateSupportTicketResponse {
  final String ticketId;

  CreateSupportTicketResponse({required this.ticketId});

  factory CreateSupportTicketResponse.fromJson(Map<String, dynamic> json) =>
      CreateSupportTicketResponse(ticketId: json['ticket_id']?.toString() ?? '');
}

class SupportTicketMessage {
  final String messageBody;
  final String senderType;

  SupportTicketMessage({
    required this.messageBody,
    required this.senderType,
  });

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) =>
      SupportTicketMessage(
        messageBody: json['message_body']?.toString() ?? '',
        senderType: json['sender_type']?.toString() ?? '',
      );
}

class SupportTicketResponse {
  final String ticketId;
  final List<SupportTicketMessage> messages;

  SupportTicketResponse({
    required this.ticketId,
    required this.messages,
  });

  factory SupportTicketResponse.fromJson(Map<String, dynamic> json) =>
      SupportTicketResponse(
        ticketId: json['ticket_id']?.toString() ?? '',
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SupportTicketMessage.fromJson)
            .toList(),
      );
}

class ImanJourneyProgressDto {
  final int prayer;
  final int quran;
  final int dhikr;

  const ImanJourneyProgressDto({
    required this.prayer,
    required this.quran,
    required this.dhikr,
  });

  factory ImanJourneyProgressDto.fromJson(Map<String, dynamic> json) =>
      ImanJourneyProgressDto(
        prayer: (json['prayer'] as num?)?.toInt() ?? 0,
        quran: (json['quran'] as num?)?.toInt() ?? 0,
        dhikr: (json['dhikr'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'prayer': prayer,
        'quran': quran,
        'dhikr': dhikr,
      };
}

class ImanJourneyFamilyReminderDto {
  final bool consentGranted;
  final String? reminderText;
  final bool notifyFamily;

  const ImanJourneyFamilyReminderDto({
    required this.consentGranted,
    required this.reminderText,
    required this.notifyFamily,
  });

  factory ImanJourneyFamilyReminderDto.fromJson(Map<String, dynamic> json) =>
      ImanJourneyFamilyReminderDto(
        consentGranted: json['consent_granted'] as bool? ?? false,
        reminderText: json['reminder_text'] as String?,
        notifyFamily: json['notify_family'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'consent_granted': consentGranted,
        'reminder_text': reminderText,
        'notify_family': notifyFamily,
      };
}

class ImanJourneyEvidenceItemDto {
  final String sourceType;
  final String sourceReference;
  final String citation;

  const ImanJourneyEvidenceItemDto({
    required this.sourceType,
    required this.sourceReference,
    required this.citation,
  });

  factory ImanJourneyEvidenceItemDto.fromJson(Map<String, dynamic> json) =>
      ImanJourneyEvidenceItemDto(
        sourceType: json['source_type']?.toString() ?? '',
        sourceReference: json['source_reference']?.toString() ?? '',
        citation: json['citation']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'source_type': sourceType,
        'source_reference': sourceReference,
        'citation': citation,
      };
}

class ImanJourneySafeFallbackDto {
  final String reason;
  final String message;

  const ImanJourneySafeFallbackDto({
    required this.reason,
    required this.message,
  });

  factory ImanJourneySafeFallbackDto.fromJson(Map<String, dynamic> json) =>
      ImanJourneySafeFallbackDto(
        reason: json['reason']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
      );
}

class ImanJourneyReligiousReminderDto {
  final String? text;
  final double confidenceScore;
  final List<ImanJourneyEvidenceItemDto> evidenceBundle;
  final ImanJourneySafeFallbackDto? safeFallback;

  const ImanJourneyReligiousReminderDto({
    required this.text,
    required this.confidenceScore,
    required this.evidenceBundle,
    required this.safeFallback,
  });

  factory ImanJourneyReligiousReminderDto.fromJson(Map<String, dynamic> json) =>
      ImanJourneyReligiousReminderDto(
        text: json['text'] as String?,
        confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
        evidenceBundle: (json['evidence_bundle'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ImanJourneyEvidenceItemDto.fromJson)
            .toList(),
        safeFallback: json['safe_fallback'] is Map<String, dynamic>
            ? ImanJourneySafeFallbackDto.fromJson(
                json['safe_fallback'] as Map<String, dynamic>,
              )
            : null,
      );
}

class ImanJourneyPrivacySettingsDto {
  final bool personalizationEnabled;
  final bool remindersEnabled;
  final bool storeJourneyEnabled;

  const ImanJourneyPrivacySettingsDto({
    required this.personalizationEnabled,
    required this.remindersEnabled,
    required this.storeJourneyEnabled,
  });

  factory ImanJourneyPrivacySettingsDto.fromJson(Map<String, dynamic> json) =>
      ImanJourneyPrivacySettingsDto(
        personalizationEnabled:
            json['personalization_enabled'] as bool? ?? false,
        remindersEnabled: json['reminders_enabled'] as bool? ?? false,
        storeJourneyEnabled: json['store_journey_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'personalization_enabled': personalizationEnabled,
        'reminders_enabled': remindersEnabled,
        'store_journey_enabled': storeJourneyEnabled,
      };
}

class ImanDuaItemDto {
  final String id;
  final String duaText;
  final bool isAnswered;

  const ImanDuaItemDto({
    required this.id,
    required this.duaText,
    required this.isAnswered,
  });

  factory ImanDuaItemDto.fromJson(Map<String, dynamic> json) => ImanDuaItemDto(
        id: json['id']?.toString() ?? '',
        duaText: json['dua_text']?.toString() ?? '',
        isAnswered: json['is_answered'] as bool? ?? false,
      );
}

class ImanJourneyResponseDto {
  final String journeyDate;
  final String todayFocus;
  final String? continueYesterdayTopic;
  final ImanJourneyProgressDto progress;
  final List<ImanDuaItemDto> personalDuaList;
  final ImanJourneyFamilyReminderDto familyReminder;
  final String? askSakinaTodayContext;
  final String? tomorrowFollowUp;
  final ImanJourneyPrivacySettingsDto privacySettings;
  final ImanJourneyReligiousReminderDto religiousReminder;

  const ImanJourneyResponseDto({
    required this.journeyDate,
    required this.todayFocus,
    required this.continueYesterdayTopic,
    required this.progress,
    required this.personalDuaList,
    required this.familyReminder,
    required this.askSakinaTodayContext,
    required this.tomorrowFollowUp,
    required this.privacySettings,
    required this.religiousReminder,
  });

  factory ImanJourneyResponseDto.fromJson(Map<String, dynamic> json) =>
      ImanJourneyResponseDto(
        journeyDate: json['journey_date']?.toString() ?? '',
        todayFocus: json['today_focus']?.toString() ?? '',
        continueYesterdayTopic: json['continue_yesterday_topic'] as String?,
        progress: ImanJourneyProgressDto.fromJson(
          json['progress'] as Map<String, dynamic>? ?? const {},
        ),
        personalDuaList:
            (json['personal_dua_list'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(ImanDuaItemDto.fromJson)
                .toList(),
        familyReminder: ImanJourneyFamilyReminderDto.fromJson(
          json['family_reminder'] as Map<String, dynamic>? ?? const {},
        ),
        askSakinaTodayContext: json['ask_sakina_today_context'] as String?,
        tomorrowFollowUp: json['tomorrow_follow_up'] as String?,
        privacySettings: ImanJourneyPrivacySettingsDto.fromJson(
          json['privacy_settings'] as Map<String, dynamic>? ?? const {},
        ),
        religiousReminder: ImanJourneyReligiousReminderDto.fromJson(
          json['religious_reminder'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

class UpsertImanJourneyRequestDto {
  final DateTime? journeyDate;
  final String todayFocus;
  final String? continueYesterdayTopic;
  final ImanJourneyProgressDto progress;
  final String? askSakinaTodayContext;
  final String? tomorrowFollowUp;
  final ImanJourneyFamilyReminderDto? familyReminder;
  final String? religiousReminderText;
  final double? religiousConfidenceScore;
  final List<ImanJourneyEvidenceItemDto>? evidenceBundle;

  const UpsertImanJourneyRequestDto({
    required this.todayFocus,
    required this.progress,
    this.journeyDate,
    this.continueYesterdayTopic,
    this.askSakinaTodayContext,
    this.tomorrowFollowUp,
    this.familyReminder,
    this.religiousReminderText,
    this.religiousConfidenceScore,
    this.evidenceBundle,
  });

  Map<String, dynamic> toJson() => {
        if (journeyDate != null) 'journey_date': journeyDate!.toIso8601String().split('T').first,
        'today_focus': todayFocus,
        'continue_yesterday_topic': continueYesterdayTopic,
        'progress': progress.toJson(),
        'ask_sakina_today_context': askSakinaTodayContext,
        'tomorrow_follow_up': tomorrowFollowUp,
        if (familyReminder != null) 'family_reminder': familyReminder!.toJson(),
        'religious_reminder_text': religiousReminderText,
        'religious_confidence_score': religiousConfidenceScore,
        if (evidenceBundle != null)
          'evidence_bundle': evidenceBundle!.map((item) => item.toJson()).toList(),
      };
}
