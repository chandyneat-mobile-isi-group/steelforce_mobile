import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/price_tier.dart';
import 'package:steelforce/features/order/domain/entities/promotion_type.dart';

/// All standard-pricing tiers for one SKU, plus whatever promotion is
/// currently attached to it. Made-to-order pricing never lives here — see
/// [MtoPricingService].
class ProductPricing extends Equatable {
  const ProductPricing({
    required this.costPrice,
    required this.standardPrice,
    required this.wholesalePrice,
    required this.dealerPrice,
    required this.vipPrice,
    required this.creditPrice,
    required this.cashPrice,
    required this.currency,
    this.promotionPrice,
    this.promotionType,
    this.promotionLabel,
  });

  final double costPrice;
  final double standardPrice;
  final double wholesalePrice;
  final double dealerPrice;
  final double vipPrice;
  final double creditPrice;
  final double cashPrice;
  final String currency;

  /// No price is known for this material.
  ///
  /// The material selection API returns **no price of any kind** — no price
  /// list, no condition, no currency, and `priceGroup` is a classification
  /// bucket rather than an amount. A material read from it therefore arrives
  /// unpriced, and this constructor says so explicitly.
  ///
  /// The alternative — zeroing the tiers and letting the UI render `$0.00` —
  /// is the failure this exists to prevent: a rep cannot tell a genuinely free
  /// line from a price the app never received, and neither can the quotation
  /// it ends up on. Callers branch on [isPriced] and render an absence.
  const ProductPricing.unpriced({this.currency = ''})
      : costPrice = 0,
        standardPrice = 0,
        wholesalePrice = 0,
        dealerPrice = 0,
        vipPrice = 0,
        creditPrice = 0,
        cashPrice = 0,
        promotionPrice = null,
        promotionType = null,
        promotionLabel = null;

  final double? promotionPrice;
  final PromotionType? promotionType;
  final String? promotionLabel;

  /// Whether an amount was actually received for this material.
  ///
  /// False for anything sourced from the selection API until a pricing
  /// endpoint exists. A false here must reach the screen as "price not
  /// available", never as a zero — see [ProductPricing.unpriced].
  bool get isPriced => standardPrice > 0;

  bool get hasPromotion =>
      promotionPrice != null && promotionPrice! < standardPrice;

  double priceFor(PriceTier tier) => switch (tier) {
        PriceTier.standard => standardPrice,
        PriceTier.wholesale => wholesalePrice,
        PriceTier.dealer => dealerPrice,
        PriceTier.vip => vipPrice,
        PriceTier.credit => creditPrice,
        PriceTier.cash => cashPrice,
      };

  double effectivePrice([PriceTier tier = PriceTier.standard]) =>
      hasPromotion ? promotionPrice! : priceFor(tier);

  @override
  List<Object?> get props => [
        costPrice,
        standardPrice,
        wholesalePrice,
        dealerPrice,
        vipPrice,
        creditPrice,
        cashPrice,
        currency,
        promotionPrice,
        promotionType,
        promotionLabel,
      ];
}
