import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/data_domain.dart'
    show CustomizationMeasurement;
import 'package:steelforce/features/order/domain/entities/fulfillment.dart';
import 'package:steelforce/features/order/domain/entities/price_tier.dart';
import 'package:steelforce/features/order/domain/entities/pricing_status.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';

/// A single line in the cart / quotation.
///
/// A line can be a plain catalog product or a **customized** one — same base
/// [product], but with category-specific [measurements], a surface
/// [appearance]/finish, an optional technical [drawingImagePath], and free-form
/// [customizationDescription]. Customized lines never merge with plain ones
/// (each customization is its own line).
///
/// ## The line owns its SKU identity, not a reference to "a product"
///
/// [product] is one `products` row, and a `products` row *is* a sellable SKU:
/// its id is `{code}-{warehouseCode}`, so [skuId] already pins down material
/// **and** stock location together. [skuCode], [materialCode] and
/// [stockLocationCode] name the three levels explicitly rather than leaving
/// callers to re-derive them from the id, which is how a "productId" starts
/// being treated as a generic product somewhere downstream.
class CartItem extends Equatable {
  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.unit,
    required this.discountPercent,
    this.leadId,
    this.depotId,
    this.priceTier = PriceTier.standard,
    this.unitPriceOverride,
    this.isManualPrice = false,
    this.fulfillment,
    this.isCustomized = false,
    this.measurements,
    this.appearance,
    this.drawingImagePath,
    this.customizationDescription,
  });

  final String id;
  final Product product;
  final double quantity;
  final String unit;
  final double discountPercent;
  final String? leadId;
  final String? depotId;

  /// Which of the SKU's price tiers this line was quoted at. Defaulted to
  /// [PriceTier.standard] because that is what the app quoted before an outlet
  /// tier existed — see the report's gaps section on `Depot.priceGroup`.
  final PriceTier priceTier;

  /// The price actually agreed for this line, frozen at the moment it was
  /// added.
  ///
  /// Null means "no snapshot taken yet" and falls back to the live catalog
  /// price, which is exactly how every line behaved before this field existed —
  /// so rows written by an older build keep pricing the way they always did.
  ///
  /// Once set it is authoritative, and deliberately so: a quotation the rep
  /// printed and handed to a depot must still say the same number tomorrow,
  /// even after SAP pushes a price delta into the `prices` table underneath it.
  final double? unitPriceOverride;

  /// Whether this unit price is an explicit manual override entered by a
  /// sales rep when backend/SAP pricing was unavailable.
  final bool isManualPrice;

  /// Pickup/delivery terms for this line, or null when the rep added it
  /// straight from the product grid without opening the fulfillment step.
  final ShipmentSelection? fulfillment;

  // ── Customization (null / false for a plain catalog line) ─────────────
  final bool isCustomized;
  final CustomizationMeasurement? measurements;
  final String? appearance;
  final String? drawingImagePath;
  final String? customizationDescription;

  // ── SKU identity ──────────────────────────────────────────────────────

  /// The exact sellable SKU: `products.id`, which equals `products.sku`.
  /// Unique per (material × warehouse).
  String get skuId => product.id;

  /// `products.sku` as SAP publishes it.
  String get skuCode => product.sku;

  /// The SAP material number, shared by every warehouse row of this material.
  String get materialCode => product.materialCode;

  /// The material/variant code, one level above the SKU: the same physical
  /// article regardless of which warehouse holds it.
  String get productCode => product.code;

  /// Where this SKU's stock sits — `products.warehouse_code`, the key the
  /// `stock` table is partitioned by.
  String get stockLocationCode => product.warehouseCode;

  // ── Money ─────────────────────────────────────────────────────────────

  /// Whether this line has an official price yet.
  ///
  /// A snapshot taken when the line was added is authoritative — it is a number
  /// the rep already quoted, so it stays [PricingStatus.available] even if the
  /// catalogue underneath later loses its price. Otherwise the live catalogue
  /// decides, and the materials API supplies no price at all, so lines sourced
  /// from it are pending until HQ says otherwise.
  /// Resolved from the amount itself, not from whether a field was set.
  ///
  /// A snapshot of `0.0` is not a price. Reading a non-null override as proof
  /// of pricing let a zero through and printed `\$0.00` on a quotation, so the
  /// test is on the resolved number: anything at or below zero is "no price
  /// yet", whatever produced it.
  PricingStatus get pricingStatus =>
      unitPrice > 0 ? PricingStatus.available : PricingStatus.waitingForHq;

  bool get isPricePending => pricingStatus.isPending;

  /// The agreed unit price, or **null** while waiting for HQ.
  ///
  /// Prefer this over [unitPrice] anywhere the value reaches a screen, a
  /// document or a total. [unitPrice] answers `0.0` for a pending line because
  /// dozens of arithmetic call sites need a double, and `0.0` rendered as
  /// `$0.00` is the exact confusion [PricingStatus] exists to prevent.
  double? get unitPriceOrNull => isPricePending ? null : unitPrice;

  double? get lineTotalOrNull => isPricePending ? null : lineTotal;

  double get unitPrice =>
      unitPriceOverride ?? product.pricing.effectivePrice(priceTier);
  double get lineSubtotal => unitPrice * quantity;
  double get lineDiscount => lineSubtotal * (discountPercent / 100);
  double get lineTotal => lineSubtotal - lineDiscount;

  CartItem copyWith({
    double? quantity,
    String? unit,
    double? discountPercent,
    PriceTier? priceTier,
    double? Function()? unitPriceOverride,
    bool? isManualPrice,
    ShipmentSelection? Function()? fulfillment,
    bool? isCustomized,
    CustomizationMeasurement? measurements,
    String? appearance,
    String? drawingImagePath,
    String? customizationDescription,
  }) {
    return CartItem(
      id: id,
      product: product,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      discountPercent: discountPercent ?? this.discountPercent,
      leadId: leadId,
      depotId: depotId,
      priceTier: priceTier ?? this.priceTier,
      // Nullable-setter closures rather than plain optionals: clearing a price
      // snapshot back to "use the live catalog price" has to be expressible,
      // and `unitPriceOverride: null` cannot say that.
      unitPriceOverride: unitPriceOverride != null
          ? unitPriceOverride()
          : this.unitPriceOverride,
      isManualPrice: isManualPrice ?? this.isManualPrice,
      fulfillment: fulfillment != null ? fulfillment() : this.fulfillment,
      isCustomized: isCustomized ?? this.isCustomized,
      measurements: measurements ?? this.measurements,
      appearance: appearance ?? this.appearance,
      drawingImagePath: drawingImagePath ?? this.drawingImagePath,
      customizationDescription:
          customizationDescription ?? this.customizationDescription,
    );
  }

  @override
  List<Object?> get props => [
        id,
        product,
        quantity,
        unit,
        discountPercent,
        leadId,
        depotId,
        priceTier,
        unitPriceOverride,
        isManualPrice,
        fulfillment,
        isCustomized,
        measurements,
        appearance,
        drawingImagePath,
        customizationDescription,
      ];
}

/// Pricing roll-ups over a set of lines.
///
/// One place, so the cart bar, the quotation preview, the detail screen and the
/// PDF cannot disagree about whether a document has a total yet.
extension CartPricing on Iterable<CartItem> {
  /// True when at least one line is still waiting for HQ.
  ///
  /// One pending line makes the **whole document** pending: a subtotal that
  /// silently omits a line is a smaller, wronger number than no subtotal at
  /// all, and it is the one a depot would be shown.
  bool get hasPendingPricing => any((item) => item.isPricePending);

  /// The document total, or null while any line is pending.
  double? get pricedSubtotal =>
      hasPendingPricing ? null : fold<double>(0, (sum, i) => sum + i.lineTotal);
}
