import 'dart:convert';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart' as local_db;

enum ChatRole {
  user,
  assistant,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.sources = const [],
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final List<Citation> sources;

  bool get isUser => role == ChatRole.user;

  local_db.Message toLocalMessage() {
    return local_db.Message(
      id: id,
      content: content,
      role: role.name,
      timestamp: timestamp.millisecondsSinceEpoch,
      sources: sources.isEmpty
          ? null
          : jsonEncode(sources.map(_citationToJson).toList()),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory ChatMessage.fromLocalMessage(local_db.Message message) {
    return ChatMessage(
      id: message.id,
      role: ChatRole.values.byName(message.role),
      content: message.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(message.timestamp),
      sources: _parseSources(message.sources),
    );
  }

  static Map<String, String?> _citationToJson(Citation citation) => {
        'title': citation.title,
        'author': citation.author,
        'chapter': citation.chapter,
        'authenticity_grade': citation.authenticityGrade,
      };

  static List<Citation> _parseSources(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((item) => Citation.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

abstract interface class ChatBackend {
  Future<RagResponse> query(String message);
}

class ApiChatBackend implements ChatBackend {
  ApiChatBackend({ApiService? api})
      : _api = api ?? ApiService(baseUrl: ApiConfig.baseUrl);

  final ApiService _api;

  @override
  Future<RagResponse> query(String message) => _api.query(message);

  void close() => _api.close();
}

abstract interface class ChatHistoryStore {
  Future<List<ChatMessage>> load();

  Future<void> save(ChatMessage message);

  Future<void> close();
}

class LocalDbChatHistoryStore implements ChatHistoryStore {
  LocalDbChatHistoryStore({
    local_db.LocalDBService? database,
    this.password = _defaultDbPassword,
  }) : _database = database ?? local_db.LocalDBService();

  static const _defaultDbPassword = String.fromEnvironment(
    'SAKINA_CHAT_DB_PASSWORD',
    defaultValue: 'sakina-local-chat-v1',
  );

  final local_db.LocalDBService _database;
  final String password;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _database.init(password);
    _initialized = true;
  }

  @override
  Future<List<ChatMessage>> load() async {
    await _ensureInitialized();
    final messages = await _database.getMessages();
    return messages.map(ChatMessage.fromLocalMessage).toList();
  }

  @override
  Future<void> save(ChatMessage message) async {
    await _ensureInitialized();
    await _database.saveMessage(message.toLocalMessage());
  }

  @override
  Future<void> close() async {
    if (_initialized) {
      await _database.close();
    }
  }
}

class ChatController {
  ChatController({
    required ChatBackend backend,
    ChatHistoryStore? historyStore,
    DateTime Function()? now,
  })  : _backend = backend,
        _historyStore = historyStore,
        _now = now ?? DateTime.now;

  final ChatBackend _backend;
  final ChatHistoryStore? _historyStore;
  final DateTime Function() _now;

  final List<ChatMessage> _messages = [];
  bool _initialized = false;
  bool _isSending = false;
  String? _errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final historyStore = _historyStore;
    if (historyStore == null) return;
    try {
      _messages
        ..clear()
        ..addAll(await historyStore.load());
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Chat history is unavailable on this device.';
    }
  }

  Future<void> send(String rawMessage) async {
    final message = rawMessage.trim();
    if (message.isEmpty || _isSending) return;

    await initialize();
    _errorMessage = null;
    _isSending = true;

    final userMessage = _newMessage(ChatRole.user, message);
    _messages.add(userMessage);
    await _saveBestEffort(userMessage);

    try {
      final response = await _backend.query(message);
      final assistantMessage = _newMessage(
        ChatRole.assistant,
        response.answer,
        sources: response.sources,
      );
      _messages.add(assistantMessage);
      await _saveBestEffort(assistantMessage);
    } catch (_) {
      _errorMessage =
          'Sakina could not reach the guidance service. Please try again.';
    } finally {
      _isSending = false;
    }
  }

  Future<void> close() async {
    if (_backend case final ApiChatBackend apiBackend) {
      apiBackend.close();
    }
    await _historyStore?.close();
  }

  ChatMessage _newMessage(
    ChatRole role,
    String content, {
    List<Citation> sources = const [],
  }) {
    final timestamp = _now();
    return ChatMessage(
      id: '${timestamp.microsecondsSinceEpoch}-${role.name}-${_messages.length}',
      role: role,
      content: content,
      timestamp: timestamp,
      sources: sources,
    );
  }

  Future<void> _saveBestEffort(ChatMessage message) async {
    try {
      await _historyStore?.save(message);
    } catch (_) {
      _errorMessage = 'Chat history is unavailable on this device.';
    }
  }
}
