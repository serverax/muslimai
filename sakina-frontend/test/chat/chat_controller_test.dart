import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/chat/chat_controller.dart';
import 'package:sakina_frontend/services/api_service.dart';

void main() {
  test('send persists user and assistant messages', () async {
    final store = _MemoryHistoryStore();
    final controller = ChatController(
      backend: _FakeBackend(
        RagResponse(
          answer: 'Wa alaikum assalam',
          sources: [
            Citation(
              title: 'Sahih al-Bukhari',
              author: 'al-Bukhari',
              authenticityGrade: 'Sahih',
            ),
          ],
          confidence: 0.91,
          guardrailTriggered: false,
          processingTimeMs: 120,
        ),
      ),
      historyStore: store,
      now: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    await controller.send(' Assalamu alaikum ');

    expect(controller.errorType, isNull);
    expect(controller.messages, hasLength(2));
    expect(controller.messages.first.role, ChatRole.user);
    expect(controller.messages.first.content, 'Assalamu alaikum');
    expect(controller.messages.last.role, ChatRole.assistant);
    expect(controller.messages.last.content, 'Wa alaikum assalam');
    expect(controller.messages.last.sources.single.title, 'Sahih al-Bukhari');
    expect(store.saved, hasLength(2));
  });

  test('initialize restores chat history', () async {
    final store = _MemoryHistoryStore()
      ..saved.add(
        ChatMessage(
          id: '1',
          role: ChatRole.user,
          content: 'Existing',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
    final controller = ChatController(
      backend: _FakeBackend(_emptyResponse),
      historyStore: store,
    );

    await controller.initialize();

    expect(controller.messages.single.content, 'Existing');
  });

  test('backend failure keeps user message and reports retryable error',
      () async {
    final controller = ChatController(
      backend: _FailingBackend(),
      historyStore: _MemoryHistoryStore(),
    );

    await controller.send('Help me');

    expect(controller.messages.single.content, 'Help me');
    expect(controller.errorType, ChatErrorType.serviceUnavailable);
    expect(controller.isSending, isFalse);
  });
}

final _emptyResponse = RagResponse(
  answer: '',
  sources: const [],
  confidence: 0,
  guardrailTriggered: false,
  processingTimeMs: 0,
);

class _FakeBackend implements ChatBackend {
  _FakeBackend(this.response);

  final RagResponse response;

  @override
  Future<RagResponse> query(String message) async => response;
}

class _FailingBackend implements ChatBackend {
  @override
  Future<RagResponse> query(String message) {
    throw ApiException('offline');
  }
}

class _MemoryHistoryStore implements ChatHistoryStore {
  final saved = <ChatMessage>[];

  @override
  Future<List<ChatMessage>> load() async => List.of(saved);

  @override
  Future<void> save(ChatMessage message) async {
    saved.add(message);
  }

  @override
  Future<void> close() async {}
}
