import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';

/// The one authority on what a depot is entitled to.
///
/// Every eligibility question in the app goes through here. Widgets render the
/// verdict and never compute one: a card that decided for itself whether 280
/// bags qualified would be a second implementation of a commercial rule, and
/// it would disagree with the real one the first time merchandising changed a
/// ladder.
///
/// **Today this is served by a published static table** — the promotion API
/// does not exist yet. The interface is shaped for that API rather than for the
/// table, so the swap is a registration change and nothing above this line
/// moves. That is also why [evaluate] is asynchronous for what is currently a
/// synchronous lookup.
abstract interface class PromotionRepository {
  /// Promotions worth showing a rep, newest-ending first.
  ///
  /// Scoped to [depotId] — an empty depot set on a promotion means
  /// everyone, a non-empty one is a negotiated deal that must not leak to
  /// other accounts. Expired promotions are never returned.
  ///
  /// [includeUpcoming] adds promotions that have not started, for the
  /// dashboard's "Upcoming" section. They are never applicable to a line.
  ResultFuture<List<Promotion>> getPromotions({
    String? depotId,
    bool includeUpcoming = false,
  });

  /// What the depot earns on this material at this quantity, or null when
  /// no promotion applies.
  ///
  /// Null is the common answer and renders as **nothing at all** — an empty
  /// promotion strip on every unpromoted product would be noise on the one
  /// screen a rep uses most.
  ResultFuture<PromotionEvaluation?> evaluate({
    required String materialCode,
    required String categoryCode,
    required int quantity,
    String? depotId,
  });
}
