import 'package:flutter/foundation.dart';

/// Safe replacements for `Enum.values.byName`.
///
/// `byName` throws `ArgumentError` on any string it does not recognise, and
/// almost every call site in this app feeds it a value that came from outside
/// the current build:
///
///  * **A Drift row written by an older version.** Renaming or removing an
///    enum value is a silent, delayed crash — the code compiles, the tests
///    pass on a fresh database, and then every existing installation throws on
///    the first read of its own data.
///  * **A server payload.** A newer backend can introduce a status this build
///    has never heard of, and the correct response is to degrade, not to take
///    the screen down.
///
/// Failing soft is right, but failing *silently* is not: a value that no
/// longer parses is a real defect and someone has to see it. So the fallback
/// path logs in debug builds and is quiet in release.
extension SafeEnumByName<T extends Enum> on List<T> {
  /// The value named [name], or null when there is no match.
  ///
  /// Use this when the caller has a genuinely better answer than a default —
  /// dropping the row, or substituting a domain-specific value.
  T? byNameOrNull(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final value in this) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// The value named [name], or [fallback] when it does not parse.
  ///
  /// [context] names the call site in the debug log, e.g. `'depots.status'`
  /// — without it the message says nothing about which column or payload was
  /// wrong, which is most of what you need to fix it.
  T byNameOr(String? name, T fallback, {String? context}) {
    final match = byNameOrNull(name);
    if (match != null) return match;

    assert(() {
      // Only when something was actually supplied. A null or empty value is
      // usually a legitimately absent field, not a mismatch worth reporting.
      if (name != null && name.isNotEmpty) {
        debugPrint(
          '[isi.warning] enum.unparsed '
          '${context == null ? '' : 'at=$context '}'
          'value=$name fallback=${fallback.name}',
        );
      }
      return true;
    }());

    return fallback;
  }
}
