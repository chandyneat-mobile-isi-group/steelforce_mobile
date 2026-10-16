import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';

/// Maps `/api/v1/mobile/materials/{material}/stock` onto [MaterialAvailability].
///
/// The endpoint answers the object envelope, so what arrives here is the `data`
/// block only:
///
/// ```json
/// {
///   "material": "1100000042",
///   "band": "High",
///   "isSellable": true,
///   "baseUnit": "KG",
///   "plants": [{"plant": "KMH2", "band": "High", "isSellable": true}],
///   "checkedAt": "2026-08-27T07:51:39.9213697+00:00"
/// }
/// ```
///
/// Two fields the entity has that this payload does not, and where they go:
///
/// * **[MaterialAvailability.status]** is derived from `isSellable`. The wire
///   has no status; SAP either will or will not accept a line.
///   [MaterialStockStatus.checking] is a client state the cubit emits while the
///   request is out, never something the server says.
/// * **[MaterialAvailability.checks]** stays empty, which is what the entity
///   already documents for a stock read. A band is not a chain of validations,
///   so [MaterialAvailability.summary] is empty too and
///   [MaterialAvailability.reason] correctly resolves to nothing — the badge
///   then falls through to its plant-list tooltip, which is the branch worth
///   having here anyway.
///
/// One consequence worth knowing: because `checks` is empty,
/// [MaterialAvailability.isInputIncomplete] is always false for a stock read.
/// That is honest rather than lossy — this endpoint takes no sales-area
/// parameters, so the `INPUT_VKORG` trap it guards against cannot occur.
class MaterialStockModel {
  const MaterialStockModel._();

  static MaterialAvailability fromJson(DataMap json) {
    final isSellable = json['isSellable'] == true;

    return MaterialAvailability(
      material: (json['material'] ?? '').toString(),
      isSellable: isSellable,
      summary: '',
      // `StockBand.parse` already lowercases, so SAP's `"High"` lands on
      // `StockBand.high` rather than throwing the way `values.byName` would.
      band: StockBand.parse(json['band']?.toString()),
      baseUnit: (json['baseUnit'] ?? '').toString(),
      plants: _plants(json['plants']),
      checkedAt: _parseCheckedAt(json['checkedAt']),
      status: isSellable
          ? MaterialStockStatus.available
          : MaterialStockStatus.unavailable,
    );
  }

  /// Blocked plants are kept, not dropped.
  ///
  /// [MaterialAvailability.sellablePlants] does the filtering for the tooltip,
  /// and throwing the blocked ones away in the model would make "KMH2 exists
  /// but will not supply this" indistinguishable from "KMH2 was never
  /// mentioned" — a difference a rep phoning a depot cares about.
  static List<MaterialPlantStock> _plants(Object? raw) =>
      (raw as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((p) => MaterialPlantStock(
                plant: (p['plant'] ?? '').toString(),
                band: StockBand.parse(p['band']?.toString()),
                isSellable: p['isSellable'] == true,
              ))
          .toList(growable: false);

  /// `.9213697` is seven fractional digits; Dart truncates past microseconds
  /// rather than rejecting, so this parses. Left in UTC — the offset is
  /// `+00:00` and any conversion for display belongs in the widget.
  static DateTime? _parseCheckedAt(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString());
}
