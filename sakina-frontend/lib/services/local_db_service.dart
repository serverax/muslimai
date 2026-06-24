import 'package:sqflite_sqlcipher/sqflite.dart';

/// Step 10 (Phase 3): encrypted local store for chat history (SQLCipher).
///
/// The DB operations require a device/FFI runtime, so they're exercised by
/// integration tests; the pure `Message` mapping is unit-tested in
/// test/local_db_test.dart.
class LocalDBService {
  static const String _dbName = 'sakina.db';
  static const int _dbVersion = 2;
  late Database _db;

  Future<void> init(String password) async {
    _db = await openDatabase(
      _dbName,
      version: _dbVersion,
      password: password, // SQLCipher encryption key
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        role TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        sources TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_messages_timestamp ON messages(timestamp DESC)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE messages ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
      );
    }
  }

  Future<void> saveMessage(Message msg) async {
    await _db.insert(
      'messages',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages() async {
    final maps = await _db.query('messages', orderBy: 'timestamp ASC');
    return maps.map(Message.fromMap).toList();
  }

  Future<void> clearMessages() async {
    await _db.delete('messages');
  }

  Future<void> close() async {
    await _db.close();
  }
}

class Message {
  final String id;
  final String content;
  final String role; // 'user' | 'assistant'
  final int timestamp;
  final String? sources;
  final String syncStatus;
  final int createdAt;

  Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.sources,
    this.syncStatus = 'synced',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content,
        'role': role,
        'timestamp': timestamp,
        'sources': sources,
        'sync_status': syncStatus,
        'created_at': createdAt,
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        content: map['content'] as String,
        role: map['role'] as String,
        timestamp: map['timestamp'] as int,
        sources: map['sources'] as String?,
        syncStatus: map['sync_status'] as String? ?? 'synced',
        createdAt: map['created_at'] as int,
      );
}
