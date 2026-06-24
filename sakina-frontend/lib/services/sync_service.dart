import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Step 11 (Phase 3): encrypted-backup crypto core.
///
/// X25519 ECDH → HKDF-SHA256 → ChaCha20-Poly1305 (AEAD). This is the
/// security-critical primitive set, written for the real `cryptography` package
/// (the roadmap's `ChaCha20Poly1305Aead()`/`Nonce` API does not exist) and
/// covered by round-trip unit tests.
///
/// The backup/restore orchestration (fetch server key, upload/download blobs)
/// is wired once ApiService exists (Step 12).
class SyncService {
  final Cipher _aead = Chacha20.poly1305Aead();
  static const int _nonceLen = 12;
  static const int _macLen = 16;

  /// Generate the client's X25519 key pair (held only on-device).
  Future<SimpleKeyPair> generateKeyPair() => X25519().newKeyPair();

  /// Derive a 32-byte symmetric key from an ECDH shared secret (HKDF-SHA256).
  Future<SecretKey> deriveSharedKey(
    SimpleKeyPair localKeyPair,
    SimplePublicKey remotePublicKey,
  ) async {
    final shared = await X25519().sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remotePublicKey,
    );
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: shared,
      nonce: const <int>[],
      info: utf8.encode('sakina-backup-v1'),
    );
  }

  /// Encrypt [plaintext] under [key]. Returns base64(nonce || cipherText || mac).
  Future<String> encryptString(String plaintext, SecretKey key) async {
    final box = await _aead.encrypt(utf8.encode(plaintext), secretKey: key);
    return base64.encode([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// Decrypt a blob produced by [encryptString].
  Future<String> decryptString(String encoded, SecretKey key) async {
    final bytes = base64.decode(encoded);
    final nonce = bytes.sublist(0, _nonceLen);
    final cipherText = bytes.sublist(_nonceLen, bytes.length - _macLen);
    final mac = Mac(bytes.sublist(bytes.length - _macLen));
    final clear = await _aead.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
    );
    return utf8.decode(clear);
  }
}
