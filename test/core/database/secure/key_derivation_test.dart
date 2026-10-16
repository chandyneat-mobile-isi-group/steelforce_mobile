import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/secure/key_derivation.dart';

void main() {
  const kd = KeyDerivation();

  group('KeyDerivation.deriveDatabaseKey', () {
    test('matches the canonical SHA-256("abc") vector', () {
      // salt + deviceKey = "a" + "bc" = "abc"; SHA-256("abc") is a well-known
      // NIST test vector, so this proves the concatenation + hashing are right
      // without re-implementing the hash in the test.
      final key = kd.deriveDatabaseKey(salt: 'a', deviceKey: 'bc');
      expect(
        key,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('produces a 64-char lowercase hex passphrase (32-byte raw key)', () {
      final key = kd.deriveDatabaseKey(
        salt: 'e7b4c92a10dcf85b4138e93d9a74fe11',
        deviceKey: 'a' * 64,
      );
      expect(key.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
    });

    test('is deterministic for identical inputs', () {
      final a = kd.deriveDatabaseKey(salt: 'salt', deviceKey: 'device');
      final b = kd.deriveDatabaseKey(salt: 'salt', deviceKey: 'device');
      expect(a, b);
    });

    test('salt and deviceKey are not interchangeable (order matters)', () {
      final ab = kd.deriveDatabaseKey(salt: 'ab', deviceKey: 'cd');
      final ba = kd.deriveDatabaseKey(salt: 'cd', deviceKey: 'ab');
      expect(ab, isNot(ba));
    });

    test('rejects empty inputs', () {
      expect(
        () => kd.deriveDatabaseKey(salt: '', deviceKey: 'x'),
        throwsArgumentError,
      );
      expect(
        () => kd.deriveDatabaseKey(salt: 'x', deviceKey: ''),
        throwsArgumentError,
      );
    });
  });
}
