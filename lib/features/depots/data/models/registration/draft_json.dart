import 'package:steelforce/core/utils/typedefs.dart';

/// Tolerant readers shared by the depot-draft response models.
///
/// A missing or mistyped optional field reads as null rather than throwing;
/// each model decides which fields it cannot do without.
abstract final class DraftJson {
  /// A non-blank string, or null. Numbers are read as their text so a code
  /// such as `"0001"` keeps its zeros and a stray `1` still reads.
  static String? string(Object? value) {
    if (value == null || value is Map || value is List) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static int? integer(Object? value) => switch (value) {
        final int n => n,
        final num n => n.toInt(),
        final String s => int.tryParse(s.trim()),
        _ => null,
      };

  static double? decimal(Object? value) {
    final n = switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.trim()),
      _ => null,
    };
    return (n == null || !n.isFinite) ? null : n;
  }

  static bool boolean(Object? value) => value == true || value == 'true';

  /// An ISO 8601 instant, or null.
  static DateTime? instant(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static DataMap? map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;

  /// The object items of a list; anything else in it is skipped.
  static Iterable<DataMap> maps(Object? value) => value is List
      ? value.whereType<Map>().map((m) => m.cast<String, dynamic>())
      : const [];
}
