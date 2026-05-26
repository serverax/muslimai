import 'package:uuid/uuid.dart';

import 'secure_key_service.dart';

class UserIdentityService {
  UserIdentityService({SecureKeyStore? keyStore})
      : _keyStore = keyStore ?? FlutterSecureKeyStore();

  static const _storageKey = 'sakina.user.id.v1';
  static const _uuid = Uuid();

  final SecureKeyStore _keyStore;

  Future<String> getOrCreateUserId() async {
    final existing = await _keyStore.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = _uuid.v4();
    await _keyStore.write(key: _storageKey, value: generated);
    return generated;
  }
}
