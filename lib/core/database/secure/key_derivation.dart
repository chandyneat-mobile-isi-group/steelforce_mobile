import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Derives the SQLCipher passphrase from the two independent secrets, exactly
/// as specified in the Blueprint §3 flow:
///
/// ```
/// FinalKey = SHA256(Env.dbSalt + DeviceKey)
/// ```
///
/// The result is a 32-byte digest returned hex-encoded (64 chars), suitable for
/// injection as a SQLCipher *raw* key (`PRAGMA key = "x'...'"`).
///
/// A plain SHA-256 (rather than a stretching KDF like PBKDF2/Argon2) is
/// deliberate and safe here: both inputs are high-entropy — `dbSalt` is a
/// random constant and `deviceKey` is 256 bits of CSPRNG output — so there is
/// no low-entropy password to protect against brute force. The salt's only role
/// is to bind the key to the (obfuscated) build, defense-in-depth on top of the
/// hardware-sealed device key.
class KeyDerivation {
  const KeyDerivation();

  /// Returns the 64-character hex passphrase for SQLCipher.
  String deriveDatabaseKey({
    required String salt,
    required String deviceKey,
  }) {
    if (salt.isEmpty || deviceKey.isEmpty) {
      throw ArgumentError('salt and deviceKey must both be non-empty');
    }
    final digest = sha256.convert(utf8.encode(salt + deviceKey));
    return digest.toString();
  }
}
