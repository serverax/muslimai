import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakina_frontend/services/api_service.dart';

void main() {
  test('query() parses RagResponse (answer + sources + confidence)', () async {
    final mock = MockClient((req) async => http.Response(
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
        ));
    final api = ApiService(baseUrl: 'http://test', client: mock);

    final r = await api.query('q');
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

  test('non-200 throws ApiException', () async {
    final mock = MockClient((req) async => http.Response('boom', 500));
    final api = ApiService(baseUrl: 'http://test', client: mock);
    expect(() => api.classify('q'), throwsA(isA<ApiException>()));
  });

  test('joinWaitlist() posts the expected payload', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(jsonEncode({'status': 'ok'}), 200);
    });
    final api = ApiService(baseUrl: 'http://test', client: mock);

    await api.joinWaitlist(
      name: 'Sakina User',
      email: 'waitlist@example.com',
      preferredLanguage: 'en',
      platform: 'web',
      message: 'Please notify me.',
    );

    expect(captured.url.toString(), 'http://test/v1/waitlist');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['name'], 'Sakina User');
    expect(body['email'], 'waitlist@example.com');
    expect(body['preferred_language'], 'en');
    expect(body['platform'], 'web');
  });
}
