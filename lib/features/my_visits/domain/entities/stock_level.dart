/// The three-tier stock status captured during a visit or depot count.
///
/// Replaces the old numeric `countedQuantity` capture: reps record how much
/// stock a shop *appears* to hold, not an exact unit count. Pure Dart — SAP
/// payload codes for these values live in the data layer
/// (`visit_capture_models.dart`), never here or in presentation.
enum StockLevel {
  low,
  medium,
  high;

  /// Canonical wire/storage name (`'low'` / `'medium'` / `'high'`).
  String get storageName => name;

  /// Parses a stored [storageName]; unknown/legacy values resolve to [low] so
  /// a drifted row degrades to the most conservative status instead of
  /// crashing a read path (reads are null-safe end to end).
  static StockLevel parse(String? value) => switch (value) {
        'medium' => StockLevel.medium,
        'high' => StockLevel.high,
        _ => StockLevel.low,
      };
}
