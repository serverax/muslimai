import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureKeyStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});
}

class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

class SecureDatabaseKeyService {
  SecureDatabaseKeyService({
    SecureKeyStore? keyStore,
    Random? random,
  })  : _keyStore = keyStore ?? FlutterSecureKeyStore(),
        _random = random ?? Random.secure();

  static const _storageKey = 'sakina.chat.sqlcipher.key.v1';
  static const _keyBytes = 32;

  final SecureKeyStore _keyStore;
  final Random _random;

  Future<String> getOrCreateDatabaseKey() async {
    final existing = await _keyStore.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final bytes = List<int>.generate(_keyBytes, (_) => _random.nextInt(256));
    final generated = base64UrlEncode(bytes);
    await _keyStore.write(key: _storageKey, value: generated);
    return generated;
  }
}
