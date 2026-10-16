import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';

/// A single sellable SKU (a size/grade/warehouse variant of some product
/// family — e.g. "SD390 Rebar 12mm" at warehouse WH-PP01). Denormalized read
/// model joined from `products` + `prices` + that row's own `stock` entry;
/// the underlying tables stay separate so the sync engine can apply
/// product/price/stock deltas independently.
///
/// [familyId]/[familyName] group sibling size/grade variants together (see
/// `getProductVariants`); [code] groups the same variant across warehouses
/// (see `getWarehouseStock`) — two different, orthogonal groupings.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.code,
    required this.sku,
    required this.materialCode,
    required this.barcode,
    required this.name,
    required this.description,
    required this.categoryId,
    this.nameKh = '',
    this.color = '',
    this.specification = '',
    this.createdAt,
    required this.subCategory,
    required this.brand,
    required this.grade,
    required this.material,
    required this.size,
    required this.diameter,
    required this.thickness,
    required this.length,
    required this.width,
    required this.height,
    required this.weight,
    required this.unit,
    required this.warehouseCode,
    required this.territory,
    required this.businessUnit,
    required this.imageUrl,
    required this.isMto,
    required this.status,
    required this.updatedAt,
    required this.pricing,
    required this.stockQuantity,
    required this.reservedQuantity,
    required this.minStock,
    required this.maxStock,
    this.stockKnown = true,
    this.isBlocked = false,
  });

  final String id;
  final String familyId;
  final String familyName;
  final String code;
  final String sku;
  final String materialCode;
  final String barcode;

  /// SAP `MaterialDes` — the English description. Kept under its original
  /// name because 33 files read it; [displayName] is the localised accessor.
  final String name;

  /// SAP `MaterialDesKH`. Empty when SAP carries no Khmer text for this
  /// material, which [LocalizedText.resolve] handles by falling back to
  /// English rather than rendering a blank row.
  ///
  /// Defaulted rather than required so the 33 existing construction sites and
  /// every fixture keep compiling — a Khmer name is genuinely optional master
  /// data, not something every caller must invent.
  final String nameKh;

  final String description;

  /// Finish / top colour. Distinct from [grade]: two coils in the same grade
  /// differ by colour, and roofing depots choose on it last.
  final String color;

  /// Free-text spec line as merchandising publishes it, for the rows where
  /// the structured dimension columns don't capture the whole story.
  final String specification;

  final String categoryId;
  final String subCategory;
  final String brand;
  final String grade;
  final String material;
  final String size;
  final double diameter;
  final double thickness;
  final double length;
  final double width;
  final double height;
  final double weight;
  final String unit;
  final String warehouseCode;
  final String territory;
  final String businessUnit;
  final String imageUrl;
  final bool isMto;
  final ProductStatus status;
  final DateTime updatedAt;

  /// When SAP first created the material. Nullable because the current extract
  /// doesn't carry it for every row, and inventing a date would be worse than
  /// admitting it is unknown.
  final DateTime? createdAt;

  final ProductPricing pricing;

  final double stockQuantity;
  final double reservedQuantity;
  final double minStock;
  final double maxStock;

  /// Whether the quantities above mean anything.
  ///
  /// False for every material read from the selection API, because **there is
  /// no on-hand quantity endpoint** — no stock level in units, no warehouse
  /// balance, no ATP. What exists instead is a live per-material sellability
  /// verdict, which answers a different question.
  ///
  /// Zero is the wrong default to render for an absent figure: "0 in stock" is
  /// a claim, and a confident wrong one. Widgets branch on this and show
  /// nothing rather than a band the data cannot support.
  final bool stockKnown;

  /// SAP has blocked this material. Never offer a blocked material for order
  /// capture — every read that leads to a quotation asks the server to exclude
  /// them, and this flag is the belt to that braces.
  final bool isBlocked;

  /// The product name in both languages. Widgets render
  /// `product.displayName.resolve(locale)` — no translation lookup, no
  /// per-locale dataset, and a language switch is a rebuild rather than a
  /// re-fetch.
  LocalizedText get displayName => LocalizedText(en: name, km: nameKh);

  /// Everything a search should match on, in every language at once.
  ///
  /// Spans both languages regardless of the active locale on purpose: a rep
  /// typing a Khmer name into an English UI is looking for that product, and
  /// returning nothing would be a defect rather than correct behaviour.
  Iterable<String> get searchableValues sync* {
    yield* displayName.allValues;
    yield code;
    yield sku;
    yield materialCode;
    yield barcode;
    yield brand;
    if (specification.trim().isNotEmpty) yield specification;
    if (color.trim().isNotEmpty) yield color;
    if (size.trim().isNotEmpty) yield size;
    if (grade.trim().isNotEmpty) yield grade;
  }

  double get availableQuantity =>
      (stockQuantity - reservedQuantity).clamp(0, double.infinity);

  /// Whether this material may be put on an order line.
  ///
  /// Note what this deliberately does *not* do when [stockKnown] is false: it
  /// does not read the absent quantity as zero. A material with no stock feed
  /// is sellable unless SAP says otherwise — the ERP's block flag is the
  /// authority there, not a number the app was never given.
  bool get isAvailable =>
      !isBlocked &&
      status == ProductStatus.active &&
      (!stockKnown || availableQuantity > 0);

  bool get isBelowMinStock => stockKnown && availableQuantity < minStock;
  bool get hasPromotion => pricing.hasPromotion;
  double get effectivePrice => pricing.effectivePrice();

  @override
  List<Object?> get props => [
        id,
        familyId,
        code,
        sku,
        materialCode,
        barcode,
        name,
        categoryId,
        subCategory,
        brand,
        warehouseCode,
        territory,
        status,
        updatedAt,
        pricing,
        nameKh,
        color,
        specification,
        stockQuantity,
        reservedQuantity,
        stockKnown,
        isBlocked,
      ];
}
