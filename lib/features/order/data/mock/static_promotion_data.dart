import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_tier.dart';

/// The promotion table, standing in for the pricing service.
///
/// TODO(release-gate): replace with the promotions endpoint when it ships.
/// This class is the *only* place any promotion is invented; everything above
/// `PromotionRepository` already talks to an interface, so the swap is a
/// registration change in `order_injection.dart` and nothing else moves.
///
/// Shaped like a published table rather than like convenient Dart: ladders
/// ascend, dates are explicit, and scope is by material or category code —
/// so the real payload maps onto it field for field instead of being reshaped
/// to fit a demo.
abstract final class StaticPromotionData {
  /// Anchored to the running clock so the demo data never silently expires,
  /// which would make every promotion vanish and look like a defect.
  static List<Promotion> promotions(DateTime now) {
    final monthStart = DateTime(now.year, now.month);
    final quarterEnd = DateTime(now.year, now.month + 3, 0);

    return [
      Promotion(
        id: 'promo_palm_roofing_fg',
        title: const LocalizedText(
          en: 'Palm Roofing Free Goods',
          km: 'ទំនិញឥតគិតថ្លៃ ផាម',
        ),
        subtitle: const LocalizedText(
          en: 'Volume incentive on Palm profile sheets',
          km: 'ការលើកទឹកចិត្តតាមបរិមាណ សម្រាប់ស័ង្កសីផាម',
        ),
        unitLabel: 'M',
        categoryCodes: const {'FG-RF'},
        validFrom: monthStart,
        validUntil: quarterEnd,
        tiers: const [
          PromotionTier(minQuantity: 300, freeQuantity: 15),
          PromotionTier(minQuantity: 500, freeQuantity: 35),
          PromotionTier(minQuantity: 2000, freeQuantity: 280),
        ],
      ),
      Promotion(
        id: 'promo_gi_coil_fg',
        title: const LocalizedText(
          en: 'GI Coil Free Goods',
          km: 'ទំនិញឥតគិតថ្លៃ ដុំដែកស័ង្កសី',
        ),
        unitLabel: 'KG',
        categoryCodes: const {'FG-COIL', 'SEMI-GI'},
        validFrom: monthStart,
        validUntil: quarterEnd,
        tiers: const [
          PromotionTier(minQuantity: 1000, freeQuantity: 40),
          PromotionTier(minQuantity: 5000, freeQuantity: 250),
        ],
      ),
      Promotion(
        id: 'promo_pipe_launch',
        title: const LocalizedText(
          en: 'Pipe Launch Incentive',
          km: 'ការលើកទឹកចិត្តបំពង់',
        ),
        subtitle: const LocalizedText(
          en: 'Starts next month',
          km: 'ចាប់ផ្តើមខែក្រោយ',
        ),
        unitLabel: 'PCS',
        categoryCodes: const {'FG-PIPE'},
        // Deliberately in the future, so the Upcoming section has something
        // real to render and its "never applicable to a line" rule is
        // exercised rather than assumed.
        validFrom: DateTime(now.year, now.month + 1, 1),
        validUntil: DateTime(now.year, now.month + 4, 0),
        tiers: const [
          PromotionTier(minQuantity: 100, freeQuantity: 4),
          PromotionTier(minQuantity: 400, freeQuantity: 20),
        ],
      ),
    ];
  }
}
