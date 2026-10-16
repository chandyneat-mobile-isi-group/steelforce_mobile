import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_tier.dart';

/// Where a promotion sits in its own lifetime, relative to today.
///
/// Derived from the dates rather than stored, so a promotion cannot be
/// mislabelled by a stale flag — and so an expired one can never be offered
/// just because nobody re-synced.
enum PromotionLifecycle {
  /// Running now, and applicable to a line today.
  active,

  /// Starts later. Worth showing a rep so they can plan a visit, never worth
  /// applying to a quotation.
  upcoming,

  /// Finished. Never shown.
  expired,
}

/// A free-goods incentive a rep can earn for a depot by ordering enough of
/// something.
///
/// ## What this is not
///
/// It is **not** a price. It carries no amount and no currency, and applying
/// one never changes the unit price of a line — it adds a separate free
/// quantity beside the paid one. That separation is the whole point: a rep
/// telling a depot "300 bags, and 15 come free" is making a different and
/// far more checkable promise than "a discount of about 5%".
///
/// ## Eligibility is not decided here
///
/// [tiers] describes the ladder; it does not decide whether this depot, on
/// this date, for this material, qualifies. That verdict comes from the
/// repository, which today reads a published static table and tomorrow reads
/// the pricing service. Re-deriving it in a widget would give the app a second
/// opinion, and the two would drift the first time a rule changed.
class Promotion extends Equatable {
  const Promotion({
    required this.id,
    required this.title,
    required this.tiers,
    required this.validFrom,
    required this.validUntil,
    this.materialCodes = const {},
    this.categoryCodes = const {},
    this.depotIds = const {},
    this.unitLabel = '',
    this.subtitle,
  });

  final String id;

  /// The rep-facing name — "Camstar Free Goods". Localised, like every other
  /// label the app renders.
  final LocalizedText title;

  final LocalizedText? subtitle;

  /// Ordered ascending by [PromotionTier.minQuantity]. Callers rely on that
  /// without re-sorting; the data layer sorts once on the way in.
  final List<PromotionTier> tiers;

  final DateTime validFrom;
  final DateTime validUntil;

  /// Which materials this applies to. Empty means "not scoped by material" —
  /// [categoryCodes] then decides.
  final Set<String> materialCodes;

  final Set<String> categoryCodes;

  /// Which depots qualify. **Empty means every depot**, which is the
  /// common case; a non-empty set is a negotiated deal for named accounts and
  /// must never leak to anyone else.
  final Set<String> depotIds;

  /// The unit the ladder counts in — "Bag", "KG". Display only; the quantity
  /// is always the line's own.
  final String unitLabel;

  PromotionLifecycle lifecycleAt(DateTime now) {
    if (now.isBefore(validFrom)) return PromotionLifecycle.upcoming;
    if (now.isAfter(validUntil)) return PromotionLifecycle.expired;
    return PromotionLifecycle.active;
  }

  /// Whether this promotion is scoped to [depotId].
  ///
  /// A null depot — a walk-in, or a quotation started before a shop was
  /// picked — matches only unscoped promotions. Showing a named account's
  /// negotiated deal to a walk-in would be a leak, not a convenience.
  bool appliesToDepot(String? depotId) {
    if (depotIds.isEmpty) return true;
    return depotId != null && depotIds.contains(depotId);
  }

  bool appliesToMaterial({
    required String materialCode,
    required String categoryCode,
  }) {
    if (materialCodes.isNotEmpty) return materialCodes.contains(materialCode);
    if (categoryCodes.isNotEmpty) return categoryCodes.contains(categoryCode);
    // Scoped to neither: a blanket promotion.
    return true;
  }

  /// The highest tier [quantity] has actually earned, or null when it has not
  /// reached the first rung.
  PromotionTier? tierFor(int quantity) {
    PromotionTier? earned;
    for (final tier in tiers) {
      if (quantity >= tier.minQuantity) {
        earned = tier;
      } else {
        break;
      }
    }
    return earned;
  }

  /// The next rung up from [quantity], or null when the ladder is topped out.
  PromotionTier? nextTierFor(int quantity) {
    for (final tier in tiers) {
      if (quantity < tier.minQuantity) return tier;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        tiers,
        validFrom,
        validUntil,
        materialCodes,
        categoryCodes,
        depotIds,
        unitLabel,
      ];
}
