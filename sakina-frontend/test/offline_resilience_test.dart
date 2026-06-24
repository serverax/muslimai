import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/chat/chat_controller.dart';
import 'package:sakina_frontend/services/api_service.dart';

class FailingBackend implements ChatBackend {
  @override
  Future<SakinaAskResponse> ask(String message) {
    throw ApiException('503 service unavailable');
  }
}

class RecordingBackend implements ChatBackend {
  final List<String> requests = [];

  @override
  Future<SakinaAskResponse> ask(String message) async {
    requests.add(message);
    return SakinaAskResponse(
      answer: 'Source-backed answer for: $message',
      language: 'en',
      intent: 'islamic_guidance',
      traceId: 'trace-recording',
      safetyState: 'ALLOWED_WITH_GUARDRAILS',
      sourcePath: const {
        'answer_source': 'rag',
        'llm_used': false,
        'blocked': false,
      },
      safety: const {
        'guardrails_passed': true,
      },
      citations: const [],
      graphPath: const [],
      ragContext: const {},
      modelProvider: 'local_db_rag_graph',
      llmModel: null,
    );
  }
}

class MemoryHistoryStore implements ChatHistoryStore {
  final Map<String, ChatMessage> rows = {};

  @override
  Future<List<ChatMessage>> load() async {
    return rows.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> save(ChatMessage message) async {
    rows[message.id] = message;
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('offline backend failure queues user message and does not fake answer',
      () async {
    final store = MemoryHistoryStore();
    final controller = ChatController(
      backend: FailingBackend(),
      historyStore: store,
      now: () => DateTime.utc(2026, 6, 5, 12),
    );

    await controller.send('Can I shorten prayers while travelling?');

    expect(controller.errorType, ChatErrorType.serviceUnavailable);
    expect(controller.messages, hasLength(1));
    expect(controller.messages.single.role, ChatRole.user);
    expect(controller.messages.single.syncStatus, ChatSyncStatus.pending);
    expect(controller.messages.where((m) => m.role == ChatRole.assistant),
        isEmpty);
    expect(store.rows.values.single.syncStatus, ChatSyncStatus.pending);
  });

  test('retryPending sends queued message to backend and marks it synced',
      () async {
    final store = MemoryHistoryStore();
    final pending = ChatMessage(
      id: 'pending-1',
      role: ChatRole.user,
      content: 'What is zakat?',
      timestamp: DateTime.utc(2026, 6, 5, 12),
      syncStatus: ChatSyncStatus.pending,
    );
    await store.save(pending);
    final backend = RecordingBackend();
    final controller = ChatController(
      backend: backend,
      historyStore: store,
      now: () => DateTime.utc(2026, 6, 5, 12, 1),
    );

    await controller.initialize();
    await controller.retryPending();

    expect(backend.requests, ['What is zakat?']);
    expect(controller.pendingMessages, isEmpty);
    expect(controller.messages.where((m) => m.role == ChatRole.assistant),
        hasLength(1));
    expect(store.rows['pending-1']!.syncStatus, ChatSyncStatus.synced);
  });
}
