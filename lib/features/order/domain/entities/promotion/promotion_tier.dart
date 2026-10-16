import 'package:equatable/equatable.dart';

/// One rung of a free-goods ladder: buy [minQuantity], get [freeQuantity].
///
/// Tiers are a *server* concept. The app never invents one and never
/// interpolates between two — a rep quoting 400 bags against a 300/500 ladder
/// gets the 300 benefit, not a pro-rated 25. Rounding a depot's entitlement
/// up or down is a commercial decision, and it is not the handset's to make.
class PromotionTier extends Equatable {
  const PromotionTier({
    required this.minQuantity,
    required this.freeQuantity,
  });

  /// The quantity a line must reach to earn this tier.
  final int minQuantity;

  /// The free quantity earned. Never added to the paid quantity — the two are
  /// carried and displayed separately all the way onto the quotation.
  final int freeQuantity;

  @override
  List<Object?> get props => [minQuantity, freeQuantity];
}
