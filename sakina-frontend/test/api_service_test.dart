import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakina_frontend/services/api_service.dart';

void main() {
  test('askSakina() parses SakinaAskResponse with citations and source path',
      () async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'answer': 'Response to: x',
            'language': 'en',
            'intent': 'wudu',
            'trace_id': 'trace-1',
            'safety_state': 'ALLOWED_WITH_GUARDRAILS',
            'source_path': {
              'local_db_checked': true,
              'rag_checked': true,
              'graph_rag_checked': true,
              'llm_used': false,
              'answer_source': 'local_db',
              'blocked': false,
            },
            'safety': {
              'pii_removed': false,
              'guardrails_passed': true,
              'crisis_detected': false,
              'out_of_scope_blocked': false,
            },
            'citations': [
              {
                'id': 'chunk-1',
                'title': 'Sahih al-Bukhari',
                'author': 'al-Bukhari',
                'chapter': 'Faith',
                'authenticity_grade': 'Sahih',
              }
            ],
            'graph_path': ['wudu'],
            'rag_context': {'status': 'checked'},
            'model_provider': 'local_db_rag_graph',
            'llm_model': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final api = ApiService(baseUrl: 'http://test', client: mock);

    final r = await api.askSakina(message: 'q');
    expect(r.answer, 'Response to: x');
    expect(r.traceId, 'trace-1');
    expect(r.safetyState, 'ALLOWED_WITH_GUARDRAILS');
    expect(r.sourcePath['answer_source'], 'local_db');
    expect(r.citations.single.title, 'Sahih al-Bukhari');
    expect(r.citations.single.authenticityGrade, 'Sahih');
  });

  test('askSakina() safely handles blocked payload', () async {
    final mock = MockClient((_) async => http.Response(
          jsonEncode({
            'answer': 'I cannot help with out-of-scope requests.',
            'language': 'en',
            'intent': 'islamic_guidance',
            'trace_id': 'trace-blocked',
            'safety_state': 'CAVEATED_SHORT_CIRCUIT',
            'source_path': {
              'local_db_checked': true,
              'rag_checked': false,
              'graph_rag_checked': false,
              'llm_used': false,
              'answer_source': 'guardrail_block',
              'blocked': true,
            },
            'safety': {
              'pii_removed': false,
              'guardrails_passed': false,
              'crisis_detected': false,
              'out_of_scope_blocked': true,
            },
            'citations': [],
            'graph_path': [],
            'rag_context': {},
            'model_provider': 'local_db_rag_graph',
          }),
          200,
        ));
    final api = ApiService(baseUrl: 'http://test', client: mock);
    final response = await api.askSakina(message: 'any question');
    expect(response.citations, isEmpty);
    expect(response.sourcePath['blocked'], isTrue);
    expect(response.safety['out_of_scope_blocked'], isTrue);
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

  test('contract errors expose status and code for gating', () async {
    final mock = MockClient((_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'subscription_required',
              'message': 'rag requires premium entitlement',
            }
          }),
          402,
        ));
    final api = ApiService(baseUrl: 'http://test', client: mock);
    try {
      await api.askSakina(message: 'q');
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 402);
      expect(e.errorCode, 'subscription_required');
    }
  });

  test('malformed add message payload throws FormatException', () async {
    final mock = MockClient((_) async => http.Response(
          jsonEncode({
            'conversation_id': 'abc',
            // user_message_id intentionally missing
          }),
          200,
        ));
    final api = ApiService(baseUrl: 'http://test', client: mock);
    expect(
      () => api.addConversationMessage(
        userId: 'user',
        conversationId: 'conversation',
        content: 'hello',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('phase3 domain wiring calls required endpoints', () async {
    final called = <String>[];
    final mock = MockClient((request) async {
      called.add('${request.method} ${request.url.path}');
      final path = request.url.path;
      if (path.endsWith('/auth/register')) {
        return http.Response(jsonEncode({'user_id': 'user-1'}), 201);
      }
      if (path.endsWith('/auth/sessions')) {
        return http.Response(jsonEncode({'session_id': 'session-1'}), 201);
      }
      if (path.endsWith('/profiles/user-1')) {
        return http.Response(jsonEncode({'user_id': 'user-1'}), 200);
      }
      if (path.endsWith('/profiles/user-1/family')) {
        return http.Response(
            jsonEncode({'family_profile_id': 'family-1'}), 201);
      }
      if (path.endsWith('/subscriptions/user-1/activate')) {
        return http.Response(jsonEncode({'subscription_id': 'sub-1'}), 201);
      }
      if (path.endsWith('/subscriptions/user-1/entitlements')) {
        return http.Response(
          jsonEncode({
            'entitlements': ['chat_premium', 'rag_verified']
          }),
          200,
        );
      }
      if (path.endsWith('/notifications/templates')) {
        return http.Response(jsonEncode({'id': 'template-1'}), 201);
      }
      if (path.endsWith('/notifications/send')) {
        return http.Response(jsonEncode({'id': 'notification-1'}), 201);
      }
      if (path.endsWith('/notifications/device-tokens')) {
        return http.Response(jsonEncode({'id': 'device-token-1'}), 201);
      }
      if (path.endsWith('/support/tickets') && request.method == 'POST') {
        return http.Response(jsonEncode({'ticket_id': 'ticket-1'}), 201);
      }
      if (path.endsWith('/support/tickets/ticket-1/messages')) {
        return http.Response(jsonEncode({'id': 'message-1'}), 201);
      }
      if (path.endsWith('/support/tickets/ticket-1') &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'ticket_id': 'ticket-1',
            'messages': [
              {'message_body': 'help', 'sender_type': 'user'}
            ],
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'error': 'not found'}), 404);
    });
    final api = ApiService(baseUrl: 'http://test', client: mock);

    final register = await api.registerUser(
      RegisterUserRequest(
        email: 'user@example.com',
        provider: 'mobile',
        providerUserId: 'mobile-123',
      ),
    );
    await api.createSession(
      CreateSessionRequest(
        userId: register.userId,
        sessionTokenHash: 'session-hash',
        refreshTokenHash: 'refresh-hash',
        expiresAt: DateTime.now().toUtc().toIso8601String(),
        refreshExpiresAt: DateTime.now().toUtc().toIso8601String(),
        ipAddress: '127.0.0.1',
        userAgent: 'test',
      ),
    );
    await api.upsertProfile(
        register.userId, UpsertProfileRequest(displayName: 'Test'));
    await api.createFamilyProfile(
      register.userId,
      CreateFamilyProfileRequest(familyName: 'Family'),
    );
    await api.activateSubscription(
      register.userId,
      ActivateSubscriptionRequest(
        providerKey: 'closed_beta_manual',
        providerDisplayName: 'Closed Beta Manual Grant',
        providerCustomerRef: 'customer-ref',
        planKey: 'premium',
        planName: 'Premium',
        billingInterval: 'monthly',
        providerSubscriptionRef: 'subscription-ref',
        providerInvoiceRef: 'invoice-ref',
        providerTransactionRef: 'transaction-ref',
        currencyCode: 'USD',
        amountMinor: 1999,
        entitlementKeys: const ['chat_premium', 'rag_verified'],
        currentPeriodStart: DateTime.now().toUtc(),
        currentPeriodEnd: DateTime.now().toUtc().add(const Duration(days: 30)),
      ),
    );
    await api.listEntitlements(register.userId);
    final templateId = await api.createNotificationTemplate(
      templateKey: 'welcome-template',
      subjectTemplate: 'Welcome',
      bodyTemplate: 'Welcome to Sakina',
    );
    await api.sendNotification(
      userId: register.userId,
      templateId: templateId,
      title: 'Title',
      body: 'Body',
    );
    await api.upsertDeviceToken(
      userId: register.userId,
      platform: 'android',
      tokenHash: 'token-hash',
    );
    final ticket = await api.createSupportTicket(
      userId: register.userId,
      subject: 'Need help',
      messageBody: 'Please help',
    );
    await api.appendSupportMessage(
      ticketId: ticket.ticketId,
      messageBody: 'Follow up',
    );
    final support = await api.getSupportTicket(ticket.ticketId);
    expect(support.messages, isNotEmpty);
    expect(
      called,
      containsAll(<String>[
        'POST /v1/auth/register',
        'POST /v1/auth/sessions',
        'PUT /v1/profiles/user-1',
        'POST /v1/profiles/user-1/family',
        'POST /v1/subscriptions/user-1/activate',
        'GET /v1/subscriptions/user-1/entitlements',
        'POST /v1/notifications/templates',
        'POST /v1/notifications/send',
        'POST /v1/notifications/device-tokens',
        'POST /v1/support/tickets',
        'POST /v1/support/tickets/ticket-1/messages',
        'GET /v1/support/tickets/ticket-1',
      ]),
    );
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
