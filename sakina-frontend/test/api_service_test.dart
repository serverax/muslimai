import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakina_frontend/config/api_config.dart';
import 'package:sakina_frontend/services/api_service.dart';

void main() {
  test('default API base URL points at production ingress host', () {
    expect(ApiConfig.baseUrl, 'https://api.sakinaapp.com');
  });

  test('query() parses RagResponse (answer + sources + confidence)', () async {
    const userId = '11111111-1111-1111-1111-111111111111';
    final mock = MockClient((req) async {
      expect(req.url.toString(), 'http://test/v1/rag/query');
      expect(req.headers['x-sakina-user-id'], userId);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['user_id'], userId);
      return http.Response(
        jsonEncode({
          'answer': 'Response to: x',
          'sources': [
            {
              'id': 'chunk-1',
              'title': 'Sahih al-Bukhari',
              'author': 'al-Bukhari',
              'chapter': 'Faith',
              'authenticity_grade': 'Sahih',
            }
          ],
          'confidence': 0.92,
          'guardrail_triggered': false,
          'processing_time_ms': 450,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(baseUrl: 'http://test', client: mock);

    final r = await api.query('q', userId: userId);
    expect(r.answer, 'Response to: x');
    expect(r.sources.single.title, 'Sahih al-Bukhari');
    expect(r.sources.single.authenticityGrade, 'Sahih');
    expect(r.confidence, 0.92);
    expect(r.guardrailTriggered, isFalse);
  });

  test('classify() parses ClassifyResponse', () async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'intent': 'FiqhQuery',
            'confidence': 0.95,
            'routing_decision': 'RAG',
          }),
          200,
        ));
    final api = ApiService(baseUrl: 'http://test', client: mock);

    final c = await api.classify('q');
    expect(c.intent, 'FiqhQuery');
    expect(c.confidence, 0.95);
    expect(c.routingDecision, 'RAG');
  });

  test('getPublicKey() parses JSON public key response', () async {
    final mock = MockClient((req) async {
      expect(req.url.toString(), 'http://test/v1/users/pubkey');
      return http.Response(jsonEncode({'pub_key': 'server-key'}), 200);
    });
    final api = ApiService(baseUrl: 'http://test', client: mock);

    expect(await api.getPublicKey(), 'server-key');
  });

  test('backup methods use user-scoped backend route', () async {
    const userId = '11111111-1111-1111-1111-111111111111';
    final seen = <String>[];
    final mock = MockClient((req) async {
      seen.add('${req.method} ${req.url}');
      expect(req.headers['x-sakina-user-id'], userId);
      if (req.method == 'POST') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['data'], 'ciphertext');
        return http.Response(jsonEncode({'success': true}), 200);
      }
      return http.Response(jsonEncode({'data': 'ciphertext'}), 200);
    });
    final api = ApiService(baseUrl: 'http://test', client: mock);

    await api.uploadBackup('ciphertext', userId: userId);
    final restored = await api.downloadBackup(userId: userId);

    expect(restored, 'ciphertext');
    expect(seen, [
      'POST http://test/v1/sync/backup/$userId',
      'GET http://test/v1/sync/backup/$userId',
    ]);
  });

  test('non-200 throws ApiException', () async {
    final mock = MockClient((req) async => http.Response('boom', 500));
    final api = ApiService(baseUrl: 'http://test', client: mock);
    expect(() => api.classify('q'), throwsA(isA<ApiException>()));
  });
}
