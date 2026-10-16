import 'dart:math';

/// RFC 4122 version 4 UUID generation.
///
/// Hand-rolled rather than pulled from the `uuid` package: `uuid` is only a
/// transitive dependency here, and importing a package we do not declare is
/// exactly the kind of thing that breaks the day an intermediate dependency
/// drops it. The algorithm is sixteen random bytes with six bits pinned, so
/// there is very little to get wrong.
///
/// [Random.secure] is used because one of the two consumers is the device
/// identifier, which lands in a server-side session record — a predictable
/// value there would let one installation guess another's id.
abstract final class Uuid {
  static final Random _random = Random.secure();

  /// A canonical lowercase v4 UUID, e.g. `a3f1c9e0-9c1e-4a7f-b0d2-1f9e4c8a2b31`.
  static String v4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Version 4 in the high nibble of byte 6, RFC 4122 variant in byte 8.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
