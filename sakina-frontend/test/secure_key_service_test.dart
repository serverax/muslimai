import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/services/secure_key_service.dart';

void main() {
  test('creates and persists a SQLCipher key in secure storage', () async {
    final store = _MemorySecureKeyStore();
    final service = SecureDatabaseKeyService(
      keyStore: store,
      random: Random(1),
    );

    final first = await service.getOrCreateDatabaseKey();
    final second = await service.getOrCreateDatabaseKey();

    expect(first, isNotEmpty);
    expect(second, first);
    expect(store.values.values.single, first);
  });

  test('reuses an existing stored SQLCipher key', () async {
    final store = _MemorySecureKeyStore()
      ..values['sakina.chat.sqlcipher.key.v1'] = 'existing-key';
    final service = SecureDatabaseKeyService(keyStore: store);

    expect(await service.getOrCreateDatabaseKey(), 'existing-key');
  });
}

class _MemorySecureKeyStore implements SecureKeyStore {
  final values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
