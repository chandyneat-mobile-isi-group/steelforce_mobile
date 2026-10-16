import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_tier.dart';

/// What one promotion is worth to one line, at one quantity.
///
/// The answer to "if I order this many, what do I get?" — resolved by the
/// repository and rendered verbatim. The card reads this; it never re-derives
/// it from [promotion]'s tiers, because two opinions on an entitlement is one
/// too many.
///
/// The four card states in the design map onto this directly:
///
/// | State | Shape |
/// |---|---|
/// | A — no promotion | no evaluation at all; nothing renders |
/// | B — eligible | [earnedTier] set |
/// | C — near the next tier | [earnedTier] null, [nextTier] set |
/// | D — multiple tiers | [promotion] has more than one tier |
class PromotionEvaluation extends Equatable {
  const PromotionEvaluation({
    required this.promotion,
    required this.quantity,
    required this.earnedTier,
    required this.nextTier,
  });

  final Promotion promotion;

  /// The quantity this verdict was computed for. Carried so a card can tell a
  /// stale evaluation from a current one while a new quantity is in flight.
  final int quantity;

  /// The tier [quantity] has earned, or null when it has not reached the first
  /// rung.
  final PromotionTier? earnedTier;

  /// The next rung up, or null when the ladder is topped out.
  final PromotionTier? nextTier;

  bool get isEligible => earnedTier != null;

  /// Free units earned right now. Zero, never null: "you have earned nothing
  /// yet" is a number, and the paid quantity stands on its own.
  int get freeQuantity => earnedTier?.freeQuantity ?? 0;

  /// How many more units would reach [nextTier], or null when there is no next
  /// rung to reach.
  ///
  /// This is what turns a promotion from a notice into a prompt — "buy 20 more
  /// bags to get 15 free" is a sentence a rep can say out loud on a shop floor.
  int? get quantityToNextTier {
    final next = nextTier;
    if (next == null) return null;
    final gap = next.minQuantity - quantity;
    return gap > 0 ? gap : null;
  }

  /// Progress towards [nextTier], 0..1, for a subtle indicator rather than a
  /// banner. Null when there is nothing left to reach.
  double? get progressToNextTier {
    final next = nextTier;
    if (next == null || next.minQuantity <= 0) return null;
    final floor = earnedTier?.minQuantity ?? 0;
    final span = next.minQuantity - floor;
    if (span <= 0) return null;
    return ((quantity - floor) / span).clamp(0.0, 1.0);
  }

  /// Whether the card should show the ladder rather than a single line.
  bool get hasMultipleTiers => promotion.tiers.length > 1;

  @override
  List<Object?> get props => [promotion, quantity, earnedTier, nextTier];
}
