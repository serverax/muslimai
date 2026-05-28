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
    throw ApiException(_errorMessage('rag/query failed', res));
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
    throw ApiException(_errorMessage('classify failed', res));
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
    throw ApiException(_errorMessage('getPublicKey failed', res));
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
      throw ApiException(_errorMessage('waitlist failed', res));
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
      throw ApiException(_errorMessage('uploadBackup failed', res));
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
    throw ApiException(_errorMessage('downloadBackup failed', res));
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
  final String title;
  final String author;
  final String? chapter;
  final String? authenticityGrade;

  Citation({
    required this.title,
    required this.author,
    this.chapter,
    this.authenticityGrade,
  });

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        chapter: json['chapter'] as String?,
        authenticityGrade: json['authenticity_grade'] as String?,
      );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
