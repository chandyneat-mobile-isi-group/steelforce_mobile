import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/mock/static_promotion_data.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/domain/repositories/promotion_repository.dart';

/// Serves promotions from the published static table.
///
/// TODO(release-gate): swap for an API-backed implementation once the
/// promotions endpoint exists. Nothing above [PromotionRepository] changes when
/// that happens — which is the reason this sits behind the interface at all
/// rather than the widgets reading a constant.
///
/// The evaluation logic here is deliberately thin: pick the applicable
/// promotion, ask it which rung the quantity has reached. It is a stand-in for
/// a server verdict, not a second implementation of one, and when the endpoint
/// lands this whole class is deleted rather than reconciled.
class StaticPromotionRepositoryImpl implements PromotionRepository {
  const StaticPromotionRepositoryImpl({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Injected so tests can sit on a fixed date rather than depending on when
  /// they run — a promotion suite that passes in June and fails in October is
  /// worse than no suite.
  final DateTime Function() _clock;

  @override
  ResultFuture<List<Promotion>> getPromotions({
    String? depotId,
    bool includeUpcoming = false,
  }) async {
    final now = _clock();
    final visible = <Promotion>[];

    for (final promotion in StaticPromotionData.promotions(now)) {
      if (!promotion.appliesToDepot(depotId)) continue;
      final lifecycle = promotion.lifecycleAt(now);
      // Expired promotions are never returned — not greyed out, not listed.
      // Offering one a rep cannot honour is worse than showing none.
      if (lifecycle == PromotionLifecycle.expired) continue;
      if (lifecycle == PromotionLifecycle.upcoming && !includeUpcoming) {
        continue;
      }
      visible.add(promotion);
    }

    // Soonest to end first: the one a rep should mention today is the one
    // about to run out.
    visible.sort((a, b) => a.validUntil.compareTo(b.validUntil));
    return Success(visible);
  }

  @override
  ResultFuture<PromotionEvaluation?> evaluate({
    required String materialCode,
    required String categoryCode,
    required int quantity,
    String? depotId,
  }) async {
    if (quantity < 0) return const Success(null);

    final now = _clock();
    for (final promotion in StaticPromotionData.promotions(now)) {
      // Active only. An upcoming promotion is worth *showing* on the
      // dashboard and never worth applying to a line.
      if (promotion.lifecycleAt(now) != PromotionLifecycle.active) continue;
      if (!promotion.appliesToDepot(depotId)) continue;
      if (!promotion.appliesToMaterial(
        materialCode: materialCode,
        categoryCode: categoryCode,
      )) {
        continue;
      }

      return Success(PromotionEvaluation(
        promotion: promotion,
        quantity: quantity,
        earnedTier: promotion.tierFor(quantity),
        nextTier: promotion.nextTierFor(quantity),
      ));
    }

    // No promotion applies. Null renders as nothing at all rather than an
    // empty strip on every unpromoted product.
    return const Success(null);
  }
}
