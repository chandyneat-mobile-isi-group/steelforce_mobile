import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';

/// Wire → domain for the material selection surface.
///
/// Kept separate from `ProductModel` on purpose. That model round-trips the
/// *catalog sync* shape — nested pricing, per-warehouse stock, a `deleted`
/// tombstone. The selection API answers something narrower and differently
/// shaped, and running one deserialiser over both would mean inventing the
/// fields the second one does not carry.
///
/// What it does not carry is the whole point of this file:
///
///  * **no price of any kind.** No price list, no condition, no scale, no
///    currency. `priceGroup` is SAP's pricing *classification* — the bucket a
///    material sits in for condition lookup — and carries no amount. It is
///    read here as an attribute and never as money.
///  * **no on-hand quantity.** No stock level in units, no warehouse balance,
///    no ATP. Sellability is a separate live call, and the rep's own eyeball
///    estimate flows the other way, with a visit.
///
/// Both absences are rendered as absences: [ProductPricing.unpriced] and
/// `stockKnown: false`. Zeroing them would put "$0.00" and "out of stock" on a
/// card, which are claims rather than gaps, and a rep cannot tell a confident
/// wrong answer from a missing one.
abstract final class MaterialApiMapper {
  /// One row of `selection/categories`.
  static MaterialCategory categoryFrom(DataMap json) {
    final code = _string(json['code']);
    final name = _string(json['name']);
    return MaterialCategory(
      code: code,
      // The server has already localised `name` from `Accept-Language`, so
      // both slots carry the same resolved string rather than the app holding
      // a translation it was never sent. Falls back to the code, which is what
      // a counter recognises anyway.
      name: LocalizedText.same(name.isEmpty ? code : name),
      materialCount: _int(json['materialCount']),
      hasPublishedSchema: json['hasPublishedSchema'] as bool? ?? false,
      icon: code,
    );
  }

  /// One row of `selection/facets`.
  ///
  /// The label is taken as sent and formatted by the caller from the step's
  /// own `unitSuffix` and `decimals` — `0.400` becomes `0.40 mm` because the
  /// *step* says so, not because this mapper guessed at a notation.
  static FilterOption facetFrom(DataMap json) => FilterOption(
        value: _string(json['value']),
        label: _string(json['label']).isEmpty
            ? _string(json['value'])
            : _string(json['label']),
        matchCount: _int(json['matchCount']),
      );

  /// One row of `selection/materials` (and of the flat catalogue list, which
  /// returns the same shape).
  ///
  /// [categoryCode] is threaded in from the selection because the list rows do
  /// not carry `materialGroupCategory` — only the detail read does. Passing the
  /// category the rep is standing in is accurate for every row of that result
  /// set and beats leaving it blank.
  static Product materialFrom(DataMap json, {String? categoryCode}) {
    final number = _string(json['material']);
    final englishName = _first([
      _string(json['materialName']),
      _string(json['name']),
    ]);
    final khmerName = _string(json['materialKhName']);
    final group = _string(json['materialGroup']);
    final groupName = _string(json['materialGroupName']);

    // `saleThicknessMm` is what you quote to a depot; `rawThicknessMm` is
    // the coil it was rolled from. They are not interchangeable and only the
    // first belongs on a quotation, so only the first is read into the
    // thickness the rest of the app renders.
    final saleThickness = _double(json['saleThicknessMm']);

    return Product(
      // The platform's row id, not the SAP number — stable, and what a detail
      // read is addressed by.
      id: _first([_string(json['id']), number]),
      // Material group doubles as the family: it is the grouping SAP publishes
      // above an individual material, and the level the `Family` facet groups
      // on.
      familyId: group,
      familyName: groupName.isEmpty ? group : groupName,
      // `code`, `sku` and `materialCode` all resolve to the SAP material
      // number here. On this data source they genuinely are one value —
      // `GetMateByPaging` returns one row per material, with no per-plant
      // duplication for a separate identity to distinguish.
      code: number,
      sku: number,
      materialCode: number,
      barcode: '',
      name: englishName.isEmpty ? number : englishName,
      nameKh: khmerName,
      description: _string(json['materialTypeName']),
      specification: _string(json['profile']),
      color: _string(json['topColor']),
      categoryId: _first([
        _string(json['materialGroupCategory']),
        categoryCode ?? '',
      ]),
      subCategory: _string(json['topColor']),
      brand: _string(json['brand']),
      grade: _string(json['grade']),
      material: _string(json['materialTypeName']),
      size: _string(json['profile']),
      diameter: 0,
      thickness: saleThickness,
      length: 0,
      width: _double(json['widthMm']),
      height: 0,
      weight: _double(json['netWeight']),
      // Varies by material — `KG` for coil, `M` for profile. Read, never
      // assumed.
      unit: _string(json['baseUnit']),
      // No plant on the material master. Left empty rather than defaulted to
      // some "main" warehouse, which would be a location the data never named.
      warehouseCode: '',
      territory: '',
      businessUnit: _string(json['divisionName']),
      imageUrl: '',
      isMto: false,
      status: (json['isBlocked'] as bool? ?? false)
          ? ProductStatus.inactive
          : ProductStatus.active,
      isBlocked: json['isBlocked'] as bool? ?? false,
      updatedAt: _time(json['synchronisedAt']) ?? DateTime.now().toUtc(),
      pricing: const ProductPricing.unpriced(),
      stockQuantity: 0,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 0,
      stockKnown: false,
    );
  }

  /// The `data` object of `GET /mobile/materials/{material}/stock`.
  ///
  /// ```jsonc
  /// { "material": "1100000042", "band": "High", "isSellable": true,
  ///   "baseUnit": "KG",
  ///   "plants": [{ "plant": "KMH2", "band": "High", "isSellable": true }],
  ///   "checkedAt": "2026-08-27T07:51:39Z" }
  /// ```
  ///
  /// `isSellable` is the verdict the order flow gates on; `band` is advisory
  /// and is shown, not enforced. A `Low` band is a warning about how much, not
  /// a refusal, so it must not disable the quantity stepper.
  ///
  /// [requested] wins over the echoed number for the same reason it does in
  /// [availabilityFrom]: the verdict is keyed by what was asked, and a server
  /// that normalised the number differently would orphan the result.
  static MaterialAvailability stockFrom(
    DataMap json, {
    required String requested,
  }) {
    final plants = (json['plants'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map((p) => MaterialPlantStock(
              plant: _string(p['plant']),
              band: StockBand.parse(p['band'] as String?),
              isSellable: p['isSellable'] as bool? ?? false,
            ))
        .toList(growable: false);

    final sellable = json['isSellable'] as bool? ?? false;
    final band = StockBand.parse(json['band'] as String?);

    return MaterialAvailability(
      material: requested,
      isSellable: sellable,
      // No prose on this endpoint, so the band is the summary. Kept human so
      // the badge's tooltip has something to say.
      summary: band == StockBand.unknown ? '' : _string(json['band']),
      band: band,
      baseUnit: _string(json['baseUnit']),
      plants: plants,
      checkedAt: _time(json['checkedAt']),
      status: sellable
          ? MaterialStockStatus.available
          : MaterialStockStatus.unavailable,
    );
  }

  /// The `data` object of `/materials/{material}/availability`.
  ///
  /// [requested] is the material number the call was made for, and it wins over
  /// whatever the body echoes: the response is keyed into a map by what was
  /// asked, and a server that normalised or trimmed the number differently
  /// would otherwise leave the result orphaned against every card.
  static MaterialAvailability availabilityFrom(
    DataMap json, {
    required String requested,
  }) {
    final checks = (json['checks'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map((c) => MaterialAvailabilityCheck(
              sequence: _string(c['sequence']),
              checkId: _string(c['checkId']),
              status: _string(c['status']),
              message: _string(c['message']),
              isVerdict: c['isVerdict'] as bool? ?? false,
            ))
        .toList(growable: false);

    final sellable = json['isSellable'] as bool? ?? false;

    return MaterialAvailability(
      material: requested,
      isSellable: sellable,
      summary: _string(json['summary']),
      checks: checks,
      status: sellable
          ? MaterialStockStatus.available
          : MaterialStockStatus.unavailable,
    );
  }

  static String _string(Object? raw) => raw is String ? raw.trim() : '';

  static String _first(List<String> candidates) => candidates.firstWhere(
        (c) => c.isNotEmpty,
        orElse: () => '',
      );

  static int _int(Object? raw) => (raw as num?)?.toInt() ?? 0;

  static double _double(Object? raw) => (raw as num?)?.toDouble() ?? 0;

  static DateTime? _time(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw)?.toUtc() : null;
}
