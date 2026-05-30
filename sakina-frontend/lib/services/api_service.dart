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
