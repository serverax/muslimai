import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sakina_frontend/services/sync_service.dart';

void main() {
  test('ChaCha20-Poly1305 encrypt/decrypt round-trips', () async {
    final svc = SyncService();
    final key = await Chacha20.poly1305Aead().newSecretKey();

    final enc = await svc.encryptString('Assalamu alaikum', key);
    expect(enc, isNot('Assalamu alaikum')); // actually encrypted
    expect(await svc.decryptString(enc, key), 'Assalamu alaikum');
  });

  test('X25519 ECDH yields a shared key both sides can use', () async {
    final svc = SyncService();
    final alice = await svc.generateKeyPair();
    final bob = await svc.generateKeyPair();

    final kAlice = await svc.deriveSharedKey(alice, await bob.extractPublicKey());
    final kBob = await svc.deriveSharedKey(bob, await alice.extractPublicKey());

    // Alice encrypts with her derived key; Bob decrypts with his — they match.
    final enc = await svc.encryptString('secret backup', kAlice);
    expect(await svc.decryptString(enc, kBob), 'secret backup');
  });

  test('wrong key fails to decrypt', () async {
    final svc = SyncService();
    final cipher = Chacha20.poly1305Aead();
    final key = await cipher.newSecretKey();
    final wrong = await cipher.newSecretKey();

    final enc = await svc.encryptString('top secret', key);
    expect(() => svc.decryptString(enc, wrong), throwsA(isA<SecretBoxAuthenticationError>()));
  });
}
