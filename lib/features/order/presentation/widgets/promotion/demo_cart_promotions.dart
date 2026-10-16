import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_tier.dart';

/// Free-goods promotions invented on the spot, so the cart badge and the PDF
/// discount column can be seen before either is wired to a real source.
///
/// **Demo only.** `PromotionCubit` and `StaticPromotionData` already exist and
/// already resolve real verdicts through the repository; this bypasses both so
/// the UI renders on every screen without a provider in scope. Deleting this
/// file and passing `PromotionCubit`'s evaluations instead is the whole of the
/// real wiring — nothing above it changes shape, because what this returns is
/// the same [PromotionEvaluation] the repository returns.
///
/// It deliberately does **not** promote every line. A demo where every card
/// wears a badge tells you nothing about how the screen reads when half of them
/// do, which is the layout that actually ships.
abstract final class DemoCartPromotions {
  /// Anchored to the running clock so the demo never silently expires and makes
  /// every badge vanish, which would look like a defect rather than a date.
  static Promotion _promotion({
    required String id,
    required String titleEn,
    required String titleKm,
    required String unitLabel,
    required List<PromotionTier> tiers,
  }) {
    final now = DateTime.now();
    return Promotion(
      id: id,
      title: LocalizedText(en: titleEn, km: titleKm),
      unitLabel: unitLabel,
      validFrom: DateTime(now.year, now.month),
      validUntil: DateTime(now.year, now.month + 3, 0),
      tiers: tiers,
    );
  }

  /// The ladder the brief asked for: buy 40, one free, rising from there.
  static Promotion get _buyFortyFreeOne => _promotion(
        id: 'demo_promo_buy40_free1',
        titleEn: 'Roofing Sheet Free Goods',
        titleKm: 'ទំនិញឥតគិតថ្លៃ ស័ង្កសី',
        unitLabel: 'Sheet',
        tiers: const [
          PromotionTier(minQuantity: 40, freeQuantity: 1),
          PromotionTier(minQuantity: 100, freeQuantity: 4),
          PromotionTier(minQuantity: 250, freeQuantity: 12),
        ],
      );

  /// A second ladder starting higher, so the demo shows two different offers
  /// rather than the same badge repeated down the list.
  static Promotion get _buyHundredFreeThree => _promotion(
        id: 'demo_promo_buy100_free3',
        titleEn: 'GI Coil Volume Bonus',
        titleKm: 'ប្រាក់រង្វាន់បរិមាណ GI',
        unitLabel: 'KG',
        tiers: const [
          PromotionTier(minQuantity: 100, freeQuantity: 3),
          PromotionTier(minQuantity: 500, freeQuantity: 20),
        ],
      );

  /// Which promotion a line gets, or null for the third of lines that get none.
  ///
  /// Keyed off the material code's hash rather than the row's position, so a
  /// line keeps its promotion when the cart is reordered or something above it
  /// is removed. A demo where the badge jumps to a different product on every
  /// delete is a demo nobody trusts.
  static Promotion? _promotionFor(CartItem item) {
    final key = item.product.materialCode.isNotEmpty
        ? item.product.materialCode
        : item.product.id;
    if (key.isEmpty) return null;

    return switch (key.hashCode.abs() % 3) {
      0 => _buyFortyFreeOne,
      1 => _buyHundredFreeThree,
      _ => null,
    };
  }

  /// The verdict for one cart line at its current quantity.
  ///
  /// Computed with the aggregate's own [Promotion.tierFor] and
  /// [Promotion.nextTierFor] rather than re-derived here, so the demo lands on
  /// exactly the rung the real repository would. A line at 30 against a 40-tier
  /// therefore comes back not-yet-eligible with a next rung to reach, which is
  /// the state the badge's prompt wording exists for.
  static PromotionEvaluation? evaluate(CartItem item) {
    final promotion = _promotionFor(item);
    if (promotion == null) return null;

    final quantity = item.quantity.round();

    return PromotionEvaluation(
      promotion: promotion,
      quantity: quantity,
      earnedTier: promotion.tierFor(quantity),
      nextTier: promotion.nextTierFor(quantity),
    );
  }

  /// Free units the line has actually earned. Zero when it has earned nothing.
  static int freeQuantityFor(CartItem item) =>
      evaluate(item)?.freeQuantity ?? 0;

  /// The rule behind those free units — "Buy 40 Free 1" — or null when the line
  /// has earned nothing. Printed on the quotation so a depot can check the
  /// entitlement rather than take it on trust.
  static String? freeRuleFor(CartItem item) {
    final tier = evaluate(item)?.earnedTier;
    if (tier == null) return null;
    return 'Buy ${tier.minQuantity} Free ${tier.freeQuantity}';
  }

  /// The campaign name, for the PDF's discount attribution.
  static String? promotionNameFor(CartItem item) {
    final evaluation = evaluate(item);
    if (evaluation == null || !evaluation.isEligible) return null;
    return evaluation.promotion.title.en;
  }
}
