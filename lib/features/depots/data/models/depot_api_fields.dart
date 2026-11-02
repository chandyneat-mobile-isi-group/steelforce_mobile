import 'package:steelforce/core/utils/typedefs.dart';

/// Field readers shared by [DepotApiMapper]'s summary and detail paths.
abstract final class DepotApiFields {
  /// The first of `salesEmployees` — the rep the depot is assigned to.
  static DataMap? primarySalesEmployee(DataMap json) {
    final raw = json['salesEmployees'];
    if (raw is! List) return null;
    return raw.whereType<Map>().firstOrNull?.cast<String, dynamic>();
  }

  static String address(DataMap json) {
    final full = json['address'];
    if (full is String && full.trim().isNotEmpty) return full.trim();
    final line1 = json['addressLine1'] as String?;
    if (line1 != null && line1.trim().isNotEmpty) return line1.trim();
    // Fall back to what the summary does carry, so a list row is not blank.
    final parts = [json['district'], json['city']]
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty);
    return parts.join(', ');
  }

  /// The province an address ends with — `Kampong Thom` from both
  /// `Kampong Thom` and `Kampong Roteh, Stueng Saen, Kampong Thom, 060803`
  /// (the trailing village code is skipped). `''` for a blank address.
  static String provinceOf(String address) {
    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    while (parts.isNotEmpty && RegExp(r'^\d+$').hasMatch(parts.last)) {
      parts.removeLast();
    }
    return parts.isEmpty ? '' : parts.last;
  }

  /// Coordinates, with `(0, 0)` treated as absent.
  ///
  /// The API sends null for both when a device reported no GPS fix, and
  /// explicitly rejects `(0, 0)` on write because it is a real point in the
  /// Gulf of Guinea — exactly what a failed fix looks like. The local schema
  /// still declares these columns non-null, so `(0, 0)` is what gets stored
  /// for "unknown"; [DepotModel] exposes `hasCoordinates` so the geofence
  /// and distance sorter can tell the difference rather than measuring to the
  /// Atlantic. See `docs/skills/api-integration.md` for the migration that makes
  /// these properly nullable.
  static (double, double) coordinates(DataMap json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    // Latitude and longitude are only ever meaningful together.
    if (lat == null || lng == null) return (0, 0);
    if (lat.abs() > 90 || lng.abs() > 180) return (0, 0);
    return (lat, lng);
  }
}
