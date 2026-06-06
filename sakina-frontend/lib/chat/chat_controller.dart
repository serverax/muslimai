import 'dart:convert';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart' as local_db;

enum ChatRole {
  user,
  assistant,
}

enum ChatSyncStatus {
  synced,
  pending,
}

enum ChatErrorType {
  historyUnavailable,
  authFailed,
  rateLimited,
  serviceUnavailable,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.sources = const [],
    this.syncStatus = ChatSyncStatus.synced,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final List<Citation> sources;
  final ChatSyncStatus syncStatus;

  bool get isUser => role == ChatRole.user;
  bool get isPending => syncStatus == ChatSyncStatus.pending;

  local_db.Message toLocalMessage() {
    return local_db.Message(
      id: id,
      content: content,
      role: role.name,
      timestamp: timestamp.millisecondsSinceEpoch,
      sources: sources.isEmpty
          ? null
          : jsonEncode(sources.map(_citationToJson).toList()),
      syncStatus: syncStatus.name,
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
      syncStatus: ChatSyncStatus.values.byName(message.syncStatus),
    );
  }

  ChatMessage withSyncStatus(ChatSyncStatus status) {
    return ChatMessage(
      id: id,
      role: role,
      content: content,
      timestamp: timestamp,
      sources: sources,
      syncStatus: status,
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
  Future<SakinaAskResponse> ask(String message);
}

class ApiChatBackend implements ChatBackend {
  ApiChatBackend({
    ApiService? api,
  }) : _api = api ?? ApiService(baseUrl: ApiConfig.baseUrl);

  final ApiService _api;

  @override
  Future<SakinaAskResponse> ask(String message) async {
    return _api.askSakina(message: message);
  }

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
  }) : _database = database ?? local_db.LocalDBService();

  final local_db.LocalDBService _database;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const password = String.fromEnvironment(
      'SAKINA_DB_KEY',
      defaultValue: 'sakina-local-db-key',
    );
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
  ChatErrorType? _errorType;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatMessage> get pendingMessages => _messages
      .where((message) => message.isUser && message.isPending)
      .toList();
  bool get isSending => _isSending;
  ChatErrorType? get errorType => _errorType;
  String? get errorMessage {
    final type = _errorType;
    if (type == null) return null;
    switch (type) {
      case ChatErrorType.historyUnavailable:
        return 'Chat history is unavailable on this device.';
      case ChatErrorType.authFailed:
        return 'Authentication failed. Please check your app configuration.';
      case ChatErrorType.rateLimited:
        return 'You are sending messages too quickly. Please wait a moment.';
      case ChatErrorType.serviceUnavailable:
        return 'Sakina could not reach the guidance service. Please try again.';
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final historyStore = _historyStore;
    if (historyStore == null) return;
    try {
      _messages
        ..clear()
        ..addAll(await historyStore.load());
      _errorType = null;
    } catch (_) {
      _errorType = ChatErrorType.historyUnavailable;
    }
  }

  Future<void> send(String rawMessage) async {
    final message = rawMessage.trim();
    if (message.isEmpty || _isSending) return;

    await initialize();
    _errorType = null;
    _isSending = true;

    final userMessage = _newMessage(ChatRole.user, message);
    _messages.add(userMessage);
    await _saveBestEffort(userMessage);

    try {
      final response = await _backend.ask(message);
      final assistantMessage = _newMessage(
        ChatRole.assistant,
        response.answer,
        sources: response.citations,
      );
      _messages.add(assistantMessage);
      await _saveBestEffort(assistantMessage);
    } on ApiException catch (error) {
      _errorType = _friendlyErrorType(error.message);
      await _markPending(userMessage);
    } catch (_) {
      _errorType = ChatErrorType.serviceUnavailable;
      await _markPending(userMessage);
    } finally {
      _isSending = false;
    }
  }

  Future<void> retryPending() async {
    await initialize();
    if (_isSending) return;
    final pending = pendingMessages;
    if (pending.isEmpty) return;

    _errorType = null;
    _isSending = true;
    try {
      for (final message in pending) {
        final response = await _backend.ask(message.content);
        await _replaceMessage(message.withSyncStatus(ChatSyncStatus.synced));
        final assistantMessage = _newMessage(
          ChatRole.assistant,
          response.answer,
          sources: response.citations,
        );
        _messages.add(assistantMessage);
        await _saveBestEffort(assistantMessage);
      }
    } on ApiException catch (error) {
      _errorType = _friendlyErrorType(error.message);
    } catch (_) {
      _errorType = ChatErrorType.serviceUnavailable;
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
      _errorType = ChatErrorType.historyUnavailable;
    }
  }

  Future<void> _markPending(ChatMessage message) async {
    await _replaceMessage(message.withSyncStatus(ChatSyncStatus.pending));
  }

  Future<void> _replaceMessage(ChatMessage replacement) async {
    final index =
        _messages.indexWhere((message) => message.id == replacement.id);
    if (index >= 0) {
      _messages[index] = replacement;
    }
    await _saveBestEffort(replacement);
  }

  ChatErrorType _friendlyErrorType(String? detail) {
    if (detail != null && detail.contains('401')) {
      return ChatErrorType.authFailed;
    }
    if (detail != null && detail.contains('429')) {
      return ChatErrorType.rateLimited;
    }
    return ChatErrorType.serviceUnavailable;
  }
}
