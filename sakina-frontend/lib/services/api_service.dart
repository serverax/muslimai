import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Step 12 (Phase 3): typed client for the Sakina backend (uses `http`).
class ApiService {
  final String baseUrl;
  final http.Client _client;
  String? _apiToken;

  ApiService({
    required this.baseUrl,
    http.Client? client,
    String? apiToken,
  })  : _client = client ?? http.Client(),
        _apiToken = apiToken;

  void setAuthToken(String? token) {
    _apiToken = token;
  }

  Future<PasswordAuthResponse> registerWithPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _post('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
      'provider': 'password',
      'provider_user_id': email.toLowerCase(),
      'metadata': {'display_name': name},
    });
    if (res.statusCode == 201) {
      final auth = PasswordAuthResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      setAuthToken(auth.accessToken);
      return auth;
    }
    throw _apiException('password register failed', res);
  }

  Future<PasswordAuthResponse> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final res = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    if (res.statusCode == 200) {
      final auth = PasswordAuthResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      setAuthToken(auth.accessToken);
      return auth;
    }
    throw _apiException('password login failed', res);
  }

  Future<PasswordAuthResponse> refreshWithToken({
    required String refreshToken,
  }) async {
    final res = await _post('/auth/refresh', {
      'refresh_token': refreshToken,
    });
    if (res.statusCode == 200) {
      final auth = PasswordAuthResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      setAuthToken(auth.accessToken);
      return auth;
    }
    throw _apiException('refresh failed', res);
  }

  Future<UserSummaryResponse> currentUser() async {
    final res = await _get('/auth/me');
    if (res.statusCode == 200) {
      return UserSummaryResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('current user failed', res);
  }

  Future<void> logout() async {
    final res = await _post('/auth/logout', {});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      setAuthToken(null);
      return;
    }
    throw _apiException('logout failed', res);
  }

  Future<SakinaAskResponse> askSakina({
    required String message,
    String language = 'auto',
    String section = 'ask_sakina',
    LocalMemoryContext? localMemoryContext,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'language': language,
      'section': section,
      if (localMemoryContext != null)
        'local_memory_context': localMemoryContext.toJson(),
    };
    final res = await _post('/api/sakina/ask', body);
    if (res.statusCode == 200) {
      return SakinaAskResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('ask Sakina failed', res);
  }

  Future<BrainChatResponse> sendBrainChat({
    required String message,
    LocalMemoryContext? localMemoryContext,
  }) async {
    final response = await askSakina(
      message: message,
      localMemoryContext: localMemoryContext,
    );
    return BrainChatResponse.fromSakinaAsk(response);
  }

  // --- Public Islamic calculators (no auth required) ---
  Future<Map<String, dynamic>> calculateZakat(Map<String, dynamic> input) async {
    final res = await _post('/api/tools/zakat', input);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _apiException('zakat calculation failed', res);
  }

  Future<Map<String, dynamic>> calculateInheritance(
      Map<String, dynamic> input) async {
    final res = await _post('/api/tools/inheritance', input);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _apiException('inheritance calculation failed', res);
  }

  Future<Map<String, dynamic>> qiblaDirection(
      {required double lat, required double lng}) async {
    final res = await _get('/api/tools/qibla?lat=$lat&lng=$lng');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _apiException('qibla lookup failed', res);
  }

  Future<Map<String, dynamic>> hijriDate(String date) async {
    final res = await _get('/api/tools/hijri?date=$date');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _apiException('hijri lookup failed', res);
  }

  // --- Scholar review status for the user's own ask trace (auth required) ---
  Future<Map<String, dynamic>> reviewStatus(String traceId) async {
    final res = await _get('/api/sakina/review-status/$traceId');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _apiException('review status lookup failed', res);
  }

  // --- PHASE 2: daily essentials ---
  Future<Map<String, dynamic>> prayerTimes({
    required double lat,
    required double lng,
    required String date,
    double tz = 0,
    String method = 'mwl',
    String asr = 'standard',
  }) async {
    final res = await _get(
        '/api/tools/prayer-times?lat=$lat&lng=$lng&date=$date&tz=$tz&method=$method&asr=$asr');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('prayer times failed', res);
  }

  Future<Map<String, dynamic>> islamicDates(String date) async {
    final res = await _get('/api/tools/islamic-dates?date=$date');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('islamic dates failed', res);
  }

  Future<Map<String, dynamic>> listDuas({String? category, String? q}) async {
    final params = <String>[];
    if (category != null && category.isNotEmpty) params.add('category=$category');
    if (q != null && q.isNotEmpty) params.add('q=${Uri.encodeQueryComponent(q)}');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await _get('/api/duas$qs');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('list duas failed', res);
  }

  Future<Map<String, dynamic>> addBookmark(
      {required String itemType, required String itemRef, String? label}) async {
    final res = await _post('/api/bookmarks',
        {'item_type': itemType, 'item_ref': itemRef, 'label': label});
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('add bookmark failed', res);
  }

  Future<Map<String, dynamic>> listBookmarks() async {
    final res = await _get('/api/bookmarks');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('list bookmarks failed', res);
  }

  Future<void> deleteBookmark(String id) async {
    final res = await _delete('/api/bookmarks/$id');
    if (res.statusCode != 200) throw _apiException('delete bookmark failed', res);
  }

  Future<Map<String, dynamic>> addReminder(
      {required String title, String? type, String? schedule}) async {
    final res = await _post('/api/reminders',
        {'title': title, 'reminder_type': type, 'schedule_rule': schedule});
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('add reminder failed', res);
  }

  Future<Map<String, dynamic>> listReminders() async {
    final res = await _get('/api/reminders');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('list reminders failed', res);
  }

  Future<void> deleteReminder(String id) async {
    final res = await _delete('/api/reminders/$id');
    if (res.statusCode != 200) throw _apiException('delete reminder failed', res);
  }

  // --- PHASE 3: Islamic corpus (public read) ---
  Future<Map<String, dynamic>> _getJsonPublic(String path) async {
    final res = await _get(path);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('corpus request failed ($path)', res);
  }

  Future<Map<String, dynamic>> quranSurahs() => _getJsonPublic('/quran/surahs');
  Future<Map<String, dynamic>> quranSurah(int surah) =>
      _getJsonPublic('/quran/surah/$surah');
  Future<Map<String, dynamic>> quranSearch(String q) =>
      _getJsonPublic('/quran/search?q=${Uri.encodeQueryComponent(q)}');
  Future<Map<String, dynamic>> quranTafsir(int surah, int ayah) =>
      _getJsonPublic('/quran/tafsir/$surah/$ayah');
  Future<Map<String, dynamic>> hadithCollections() =>
      _getJsonPublic('/hadith/collections');
  Future<Map<String, dynamic>> hadithSearch(String q) =>
      _getJsonPublic('/hadith/search?q=${Uri.encodeQueryComponent(q)}');
  Future<Map<String, dynamic>> islamicSources() => _getJsonPublic('/islamic-sources');

  // --- PHASE 4: guides / kids / masjid (public read; kids progress login) ---
  Future<Map<String, dynamic>> guide(String slug) => _getJsonPublic('/guides/$slug');
  Future<Map<String, dynamic>> newMuslimSteps() => _getJsonPublic('/new-muslim/steps');
  Future<Map<String, dynamic>> kidsQuiz() => _getJsonPublic('/kids/quiz');
  Future<Map<String, dynamic>> kidsLessons() => _getJsonPublic('/kids/lessons');
  Future<Map<String, dynamic>> masjidNearby({double? lat, double? lng}) =>
      _getJsonPublic('/masjid/nearby?lat=${lat ?? ''}&lng=${lng ?? ''}');

  Future<void> saveKidsProgress(
      {required String activity, required int score, required int total}) async {
    final res = await _post(
        '/kids/progress', {'activity': activity, 'score': score, 'total': total});
    if (res.statusCode != 201) throw _apiException('save kids progress failed', res);
  }

  // --- PHASE 5: subscriptions / entitlements / payment ---
  Future<Map<String, dynamic>> subscriptionPlans() => _getJsonPublic('/subscription/plans');
  Future<Map<String, dynamic>> paymentProviderStatus() =>
      _getJsonPublic('/payment/provider-status');

  Future<Map<String, dynamic>> subscriptionMe() async {
    final res = await _get('/subscription/me');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('subscription lookup failed', res);
  }

  Future<Map<String, dynamic>> entitlementsMe() async {
    final res = await _get('/entitlements/me');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('entitlements lookup failed', res);
  }

  Future<Map<String, dynamic>> createCheckoutSession() async {
    final res = await _post('/payment/create-checkout-session', {});
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw _apiException('checkout failed', res);
  }

  Future<UserLearningProfileResponse> getUserLearningProfile() async {
    final res = await _get('/api/user-learning/profile');
    if (res.statusCode == 200) {
      return UserLearningProfileResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('user learning profile failed', res);
  }

  Future<void> updateUserLearningConsent({
    required bool learningEnabled,
    required bool localMemoryEnabled,
    required bool serverMemoryEnabled,
  }) async {
    final res = await _post('/api/user-learning/consent', {
      'learning_enabled': learningEnabled,
      'local_memory_enabled': localMemoryEnabled,
      'server_memory_enabled': serverMemoryEnabled,
    });
    if (res.statusCode == 200) {
      return;
    }
    throw _apiException('user learning consent failed', res);
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
      return SessionResponse.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('create session failed', res);
  }

  Future<ProfileResponse> upsertProfile(
    String userId,
    UpsertProfileRequest request,
  ) async {
    final res =
        await _put('/profiles/$userId', request.toJson(), userId: userId);
    if (res.statusCode == 200) {
      return ProfileResponse.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('upsert profile failed', res);
  }

  Future<FamilyProfileResponse> createFamilyProfile(
    String userId,
    CreateFamilyProfileRequest request,
  ) async {
    final res = await _post('/profiles/$userId/family', request.toJson(),
        userId: userId);
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
    final res =
        await _get('/subscriptions/$userId/entitlements', userId: userId);
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['entitlements'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
    }
    throw _apiException('list entitlements failed', res);
  }

  Future<AccountDeletionRequestResponse> requestAccountDeletion() async {
    final res = await _post('/account/delete-request', const {});
    if (res.statusCode == 202) {
      return AccountDeletionRequestResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('request account deletion failed', res);
  }

  Future<AccountDeletionRequestResponse> requestDataExport() async {
    final res = await _post('/account/export-request', const {});
    if (res.statusCode == 202) {
      return AccountDeletionRequestResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('request data export failed', res);
  }

  Future<List<IslamicSourceDto>> getIslamicSources({
    String? language,
    String? source,
  }) async {
    final query = <String, String>{};
    if (language != null && language.isNotEmpty) query['language'] = language;
    if (source != null && source.isNotEmpty) query['source'] = source;
    final uri = Uri.parse(_endpoint('/islamic/sources'))
        .replace(queryParameters: query);
    final res = await _withRetry(
      () => _client
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 30)),
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
    final uri = Uri.parse(_endpoint('/islamic/documents'))
        .replace(queryParameters: query);
    final res = await _withRetry(
      () => _client
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 30)),
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
    final uri = Uri.parse(_endpoint('/islamic/search'))
        .replace(queryParameters: params);
    final res = await _withRetry(
      () => _client
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 30)),
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
      return IslamicAskResponseDto.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
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
      return AddMessageResponse.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
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

  Future<List<UserNotificationDto>> listNotifications() async {
    final res = await _get('/notifications');
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['notifications'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(UserNotificationDto.fromJson)
          .toList();
    }
    throw _apiException('list notifications failed', res);
  }

  Future<UserNotificationDto> markNotificationRead({
    required String notificationId,
  }) async {
    final res = await _post('/notifications/$notificationId/read', {});
    if (res.statusCode == 200) {
      return UserNotificationDto.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('mark notification read failed', res);
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
      return ImanDuaItemDto.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw _apiException('add dua item failed', res);
  }

  Future<MemoryWriteResponse> writeMemory(
    MemoryWriteRequest request,
  ) async {
    final res = await _post(
      '/api/memory/write',
      request.toJson(),
      userId: request.userId,
    );
    if (res.statusCode == 200) {
      return MemoryWriteResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('write memory failed', res);
  }

  Future<MemoryEntryResponse> readMemory({
    required String userId,
    required String memoryKey,
  }) async {
    final encodedKey = Uri.encodeQueryComponent(memoryKey);
    final res = await _get(
      '/api/memory/read?user_id=$userId&memory_key=$encodedKey',
      userId: userId,
    );
    if (res.statusCode == 200) {
      return MemoryEntryResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('read memory failed', res);
  }

  Future<int> deleteMemory({
    required String userId,
    required String memoryKey,
  }) async {
    final encodedKey = Uri.encodeQueryComponent(memoryKey);
    final res = await _delete(
      '/api/memory/delete?user_id=$userId&memory_key=$encodedKey',
      userId: userId,
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return (decoded['deleted'] as num?)?.toInt() ?? 0;
    }
    throw _apiException('delete memory failed', res);
  }

  Future<MultimodalAnalysisResponse> analyzeMultimodal({
    required Uint8List bytes,
    required String filename,
    required String assetType,
    required String mimeType,
    required String language,
    String? requestId,
  }) async {
    final traceId =
        requestId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final streamed = await _withStreamRetry(
      () {
        final multipart = http.MultipartRequest(
          'POST',
          Uri.parse(_endpoint('/api/multimodal/analyze')),
        );
        final token = _apiToken;
        if (token != null && token.isNotEmpty) {
          multipart.headers['Authorization'] = 'Bearer $token';
        }
        multipart.headers['x-request-id'] = traceId;
        multipart.fields['asset_type'] = assetType;
        multipart.fields['mime_type'] = mimeType;
        multipart.fields['language'] = language;
        multipart.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ));
        return _client.send(multipart).timeout(const Duration(seconds: 90));
      },
    );
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return MultimodalAnalysisResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _apiException('multimodal analysis failed', res);
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

  Future<http.StreamedResponse> _withStreamRetry(
    Future<http.StreamedResponse> Function() run,
  ) async {
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
    throw ApiException('stream request failed after retries: $lastError');
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

  Future<http.Response> _delete(String path, {String? userId}) {
    return _withRetry(
      () => _client
          .delete(Uri.parse(_endpoint(path)), headers: _headers(userId: userId))
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

class LocalMemoryContext {
  final String? preferredLanguage;
  final String? answerStyle;
  final bool consent;
  final String? lastSyncAt;

  const LocalMemoryContext({
    this.preferredLanguage,
    this.answerStyle,
    required this.consent,
    this.lastSyncAt,
  });

  Map<String, dynamic> toJson() => {
        if (preferredLanguage != null) 'preferred_language': preferredLanguage,
        if (answerStyle != null) 'answer_style': answerStyle,
        'consent': consent,
        if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      };
}

class SakinaAskResponse {
  final String answer;
  final String language;
  final String intent;
  final String traceId;
  final String safetyState;
  final Map<String, dynamic> sourcePath;
  final Map<String, dynamic> safety;
  final List<Citation> citations;
  final List<dynamic> graphPath;
  final Map<String, dynamic> ragContext;
  final String modelProvider;
  final String? llmModel;

  const SakinaAskResponse({
    required this.answer,
    required this.language,
    required this.intent,
    required this.traceId,
    required this.safetyState,
    required this.sourcePath,
    required this.safety,
    required this.citations,
    required this.graphPath,
    required this.ragContext,
    required this.modelProvider,
    required this.llmModel,
  });

  factory SakinaAskResponse.fromJson(Map<String, dynamic> json) {
    return SakinaAskResponse(
      answer: json['answer']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      intent: json['intent']?.toString() ?? '',
      traceId: json['trace_id']?.toString() ?? '',
      safetyState: json['safety_state']?.toString() ?? '',
      sourcePath: json['source_path'] is Map<String, dynamic>
          ? json['source_path'] as Map<String, dynamic>
          : const {},
      safety: json['safety'] is Map<String, dynamic>
          ? json['safety'] as Map<String, dynamic>
          : const {},
      citations: (json['citations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Citation.fromJson)
          .toList(),
      graphPath: json['graph_path'] as List<dynamic>? ?? const [],
      ragContext: json['rag_context'] is Map<String, dynamic>
          ? json['rag_context'] as Map<String, dynamic>
          : const {},
      modelProvider: json['model_provider']?.toString() ?? '',
      llmModel: json['llm_model']?.toString(),
    );
  }
}

class BrainChatResponse {
  final String workspaceId;
  final String brainTraceId;
  final String workflow;
  final String languageDetected;
  final bool usedLocalMemory;
  final String memoryWriteStatus;
  final String? learnedPreference;
  final Map<String, dynamic> memoryUpdateSuggestion;
  final List<String> agentsExecuted;
  final List<dynamic> ragResults;
  final List<dynamic> graphPath;
  final List<Citation> citations;
  final Map<String, dynamic> evaluationResult;
  final Map<String, dynamic> cacheDecision;
  final Map<String, dynamic> routerDecision;
  final String modelProvider;
  final Map<String, dynamic> ollamaStatus;
  final String finalAnswer;

  const BrainChatResponse({
    required this.workspaceId,
    required this.brainTraceId,
    required this.workflow,
    required this.languageDetected,
    required this.usedLocalMemory,
    required this.memoryWriteStatus,
    required this.learnedPreference,
    required this.memoryUpdateSuggestion,
    required this.agentsExecuted,
    required this.ragResults,
    required this.graphPath,
    required this.citations,
    required this.evaluationResult,
    required this.cacheDecision,
    required this.routerDecision,
    required this.modelProvider,
    required this.ollamaStatus,
    required this.finalAnswer,
  });

  factory BrainChatResponse.fromSakinaAsk(SakinaAskResponse response) =>
      BrainChatResponse(
        workspaceId: '',
        brainTraceId: response.traceId,
        workflow: response.sourcePath['answer_source']?.toString() ?? '',
        languageDetected: response.language,
        usedLocalMemory: false,
        memoryWriteStatus: '',
        learnedPreference: null,
        memoryUpdateSuggestion: const {},
        agentsExecuted: const ['sakina_mother_algorithm'],
        ragResults:
            response.ragContext.isEmpty ? const [] : [response.ragContext],
        graphPath: response.graphPath,
        citations: response.citations,
        evaluationResult: {
          'guardrails_passed': response.safety['guardrails_passed'] == true,
          'safety_state': response.safetyState,
          'source_path': response.sourcePath,
        },
        cacheDecision: const {},
        routerDecision: response.sourcePath,
        modelProvider: response.modelProvider,
        ollamaStatus: {
          'model': response.llmModel,
          'llm_used': response.sourcePath['llm_used'] == true,
        },
        finalAnswer: response.answer,
      );

  factory BrainChatResponse.fromJson(Map<String, dynamic> json) =>
      BrainChatResponse(
        workspaceId: json['workspace_id']?.toString() ?? '',
        brainTraceId: json['brain_trace_id']?.toString() ?? '',
        workflow: json['workflow']?.toString() ?? '',
        languageDetected: json['language_detected']?.toString() ?? '',
        usedLocalMemory: json['used_local_memory'] as bool? ?? false,
        memoryWriteStatus: json['memory_write_status']?.toString() ?? '',
        learnedPreference: json['learned_preference']?.toString(),
        memoryUpdateSuggestion:
            json['memory_update_suggestion'] is Map<String, dynamic>
                ? json['memory_update_suggestion'] as Map<String, dynamic>
                : const {},
        agentsExecuted: (json['agents_executed'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        ragResults: json['rag_results'] as List<dynamic>? ?? const [],
        graphPath: json['graph_path'] as List<dynamic>? ?? const [],
        citations: (json['citations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Citation.fromJson)
            .toList(),
        evaluationResult: json['evaluation_result'] is Map<String, dynamic>
            ? json['evaluation_result'] as Map<String, dynamic>
            : const {},
        cacheDecision: json['cache_decision'] is Map<String, dynamic>
            ? json['cache_decision'] as Map<String, dynamic>
            : const {},
        routerDecision: json['router_decision'] is Map<String, dynamic>
            ? json['router_decision'] as Map<String, dynamic>
            : const {},
        modelProvider: json['model_provider']?.toString() ?? '',
        ollamaStatus: json['ollama_status'] is Map<String, dynamic>
            ? json['ollama_status'] as Map<String, dynamic>
            : const {},
        finalAnswer: json['final_answer']?.toString() ?? '',
      );
}

class UserLearningProfileResponse {
  final String workspaceId;
  final Map<String, dynamic> permissions;
  final List<Map<String, dynamic>> preferences;

  const UserLearningProfileResponse({
    required this.workspaceId,
    required this.permissions,
    required this.preferences,
  });

  factory UserLearningProfileResponse.fromJson(Map<String, dynamic> json) =>
      UserLearningProfileResponse(
        workspaceId: json['workspace_id']?.toString() ?? '',
        permissions: json['permissions'] is Map<String, dynamic>
            ? json['permissions'] as Map<String, dynamic>
            : const {},
        preferences: (json['preferences'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
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

  factory IslamicSourceDto.fromJson(Map<String, dynamic> json) =>
      IslamicSourceDto(
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

  factory IslamicChunkDto.fromJson(Map<String, dynamic> json) =>
      IslamicChunkDto(
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

class MemoryWriteRequest {
  final String userId;
  final String memoryKey;
  final String memoryType;
  final Map<String, dynamic> payload;
  final String sourceLanguage;
  final bool consentRequired;
  final bool consentGranted;

  const MemoryWriteRequest({
    required this.userId,
    required this.memoryKey,
    required this.memoryType,
    required this.payload,
    required this.sourceLanguage,
    required this.consentRequired,
    required this.consentGranted,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'memory_key': memoryKey,
        'memory_type': memoryType,
        'payload': payload,
        'source_language': sourceLanguage,
        'consent_required': consentRequired,
        'consent_granted': consentGranted,
      };
}

class MemoryWriteResponse {
  final bool stored;
  final bool allowed;
  final String sensitivityLevel;
  final String reason;
  final String? memoryId;

  const MemoryWriteResponse({
    required this.stored,
    required this.allowed,
    required this.sensitivityLevel,
    required this.reason,
    required this.memoryId,
  });

  factory MemoryWriteResponse.fromJson(Map<String, dynamic> json) =>
      MemoryWriteResponse(
        stored: json['stored'] as bool? ?? false,
        allowed: json['allowed'] as bool? ?? false,
        sensitivityLevel: json['sensitivity_level']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        memoryId: json['memory_id']?.toString(),
      );
}

class MemoryEntryResponse {
  final String id;
  final String userId;
  final String memoryKey;
  final String memoryType;
  final String sensitivityLevel;
  final Map<String, dynamic> payload;
  final String sourceLanguage;
  final bool consentRequired;
  final bool consentGranted;
  final bool allowed;

  const MemoryEntryResponse({
    required this.id,
    required this.userId,
    required this.memoryKey,
    required this.memoryType,
    required this.sensitivityLevel,
    required this.payload,
    required this.sourceLanguage,
    required this.consentRequired,
    required this.consentGranted,
    required this.allowed,
  });

  factory MemoryEntryResponse.fromJson(Map<String, dynamic> json) =>
      MemoryEntryResponse(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        memoryKey: json['memory_key']?.toString() ?? '',
        memoryType: json['memory_type']?.toString() ?? '',
        sensitivityLevel: json['sensitivity_level']?.toString() ?? '',
        payload: json['payload'] is Map<String, dynamic>
            ? json['payload'] as Map<String, dynamic>
            : const {},
        sourceLanguage: json['source_language']?.toString() ?? '',
        consentRequired: json['consent_required'] as bool? ?? false,
        consentGranted: json['consent_granted'] as bool? ?? false,
        allowed: json['allowed'] as bool? ?? false,
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

class PasswordAuthResponse {
  final String userId;
  final String accessToken;
  final String refreshToken;
  final String? email;

  PasswordAuthResponse({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    this.email,
  });

  factory PasswordAuthResponse.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token']?.toString() ?? '';
    if (accessToken.isEmpty) {
      throw const FormatException('missing access_token in auth response');
    }
    return PasswordAuthResponse(
      userId: json['user_id']?.toString() ?? '',
      accessToken: accessToken,
      refreshToken: json['refresh_token']?.toString() ?? '',
      email: json['email']?.toString(),
    );
  }
}

class UserSummaryResponse {
  final String userId;
  final String email;

  const UserSummaryResponse({
    required this.userId,
    required this.email,
  });

  factory UserSummaryResponse.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id']?.toString() ?? '';
    if (userId.isEmpty) {
      throw const FormatException('missing user_id in current user response');
    }
    return UserSummaryResponse(
      userId: userId,
      email: json['email']?.toString() ?? '',
    );
  }
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

  factory ProfileResponse.fromJson(Map<String, dynamic> json) =>
      ProfileResponse(
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
  final String providerDisplayName;
  final String providerCustomerRef;
  final String planKey;
  final String planName;
  final String billingInterval;
  final String providerSubscriptionRef;
  final String providerInvoiceRef;
  final String providerTransactionRef;
  final String currencyCode;
  final int amountMinor;
  final List<String> entitlementKeys;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;

  ActivateSubscriptionRequest({
    required this.providerKey,
    required this.providerDisplayName,
    required this.providerCustomerRef,
    required this.planKey,
    required this.planName,
    required this.billingInterval,
    required this.providerSubscriptionRef,
    required this.providerInvoiceRef,
    required this.providerTransactionRef,
    required this.currencyCode,
    required this.amountMinor,
    required this.entitlementKeys,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
  });

  Map<String, dynamic> toJson() => {
        'provider_key': providerKey,
        'provider_display_name': providerDisplayName,
        'provider_customer_ref': providerCustomerRef,
        'plan_key': planKey,
        'plan_name': planName,
        'billing_interval': billingInterval,
        'provider_subscription_ref': providerSubscriptionRef,
        'provider_invoice_ref': providerInvoiceRef,
        'provider_transaction_ref': providerTransactionRef,
        'currency_code': currencyCode,
        'amount_minor': amountMinor,
        'current_period_start': currentPeriodStart.toUtc().toIso8601String(),
        'current_period_end': currentPeriodEnd.toUtc().toIso8601String(),
        'entitlement_keys': entitlementKeys,
      };
}

class SubscriptionResponse {
  final String subscriptionId;

  SubscriptionResponse({required this.subscriptionId});

  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) =>
      SubscriptionResponse(
        subscriptionId: json['subscription_id']?.toString() ?? '',
      );
}

class AccountDeletionRequestResponse {
  final String status;
  final String requestId;
  final int auditId;
  final String outboxEventId;

  AccountDeletionRequestResponse({
    required this.status,
    required this.requestId,
    required this.auditId,
    required this.outboxEventId,
  });

  factory AccountDeletionRequestResponse.fromJson(Map<String, dynamic> json) =>
      AccountDeletionRequestResponse(
        status: json['status']?.toString() ?? '',
        requestId: json['request_id']?.toString() ?? '',
        auditId: (json['audit_id'] as num?)?.toInt() ?? 0,
        outboxEventId: json['outbox_event_id']?.toString() ?? '',
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
  final String? assistantMessageId;
  final String? answer;
  final String? traceId;

  AddMessageResponse({
    required this.conversationId,
    required this.userMessageId,
    this.assistantMessageId,
    this.answer,
    this.traceId,
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
      assistantMessageId: json['assistant_message_id']?.toString(),
      answer: json['response']?.toString(),
      traceId: json['trace_id']?.toString(),
    );
  }
}

class CreateSupportTicketResponse {
  final String ticketId;

  CreateSupportTicketResponse({required this.ticketId});

  factory CreateSupportTicketResponse.fromJson(Map<String, dynamic> json) =>
      CreateSupportTicketResponse(
          ticketId: json['ticket_id']?.toString() ?? '');
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
        if (journeyDate != null)
          'journey_date': journeyDate!.toIso8601String().split('T').first,
        'today_focus': todayFocus,
        'continue_yesterday_topic': continueYesterdayTopic,
        'progress': progress.toJson(),
        'ask_sakina_today_context': askSakinaTodayContext,
        'tomorrow_follow_up': tomorrowFollowUp,
        if (familyReminder != null) 'family_reminder': familyReminder!.toJson(),
        'religious_reminder_text': religiousReminderText,
        'religious_confidence_score': religiousConfidenceScore,
        if (evidenceBundle != null)
          'evidence_bundle':
              evidenceBundle!.map((item) => item.toJson()).toList(),
      };
}

class UserNotificationDto {
  final String id;
  final String channel;
  final String status;
  final String? title;
  final String? body;
  final Map<String, dynamic> payload;
  final String? scheduledAt;
  final String? sentAt;
  final String? readAt;
  final String createdAt;

  const UserNotificationDto({
    required this.id,
    required this.channel,
    required this.status,
    required this.payload,
    required this.createdAt,
    this.title,
    this.body,
    this.scheduledAt,
    this.sentAt,
    this.readAt,
  });

  factory UserNotificationDto.fromJson(Map<String, dynamic> json) =>
      UserNotificationDto(
        id: json['id']?.toString() ?? '',
        channel: json['channel']?.toString() ?? '',
        status: json['notification_status']?.toString() ??
            json['status']?.toString() ??
            '',
        title: json['title']?.toString(),
        body: json['body']?.toString(),
        payload: json['payload'] is Map<String, dynamic>
            ? json['payload'] as Map<String, dynamic>
            : const {},
        scheduledAt: json['scheduled_at']?.toString(),
        sentAt: json['sent_at']?.toString(),
        readAt: json['read_at']?.toString(),
        createdAt: json['created_at']?.toString() ?? '',
      );
}

class MultimodalAnalysisResponse {
  final String assetId;
  final String traceId;
  final String status;
  final String extractedText;
  final String redactedText;
  final String provider;
  final String safetyLevel;
  final String workspaceScope;
  final Map<String, dynamic> islamicAnswer;

  const MultimodalAnalysisResponse({
    required this.assetId,
    required this.traceId,
    required this.status,
    required this.extractedText,
    required this.redactedText,
    required this.provider,
    required this.safetyLevel,
    required this.workspaceScope,
    required this.islamicAnswer,
  });

  factory MultimodalAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final assetId = json['asset_id']?.toString() ?? '';
    if (assetId.isEmpty) {
      throw const FormatException('missing asset_id in multimodal response');
    }
    final answer = json['islamic_answer'];
    return MultimodalAnalysisResponse(
      assetId: assetId,
      traceId: json['trace_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      extractedText: json['extracted_text']?.toString() ?? '',
      redactedText: json['redacted_text']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      safetyLevel: json['safety_level']?.toString() ?? '',
      workspaceScope: json['workspace_scope']?.toString() ?? '',
      islamicAnswer: answer is Map<String, dynamic> ? answer : const {},
    );
  }

  String get answerText => islamicAnswer['answer']?.toString() ?? '';

  List<Citation> get citations =>
      (islamicAnswer['citations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Citation.fromJson)
          .toList();
}
