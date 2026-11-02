import 'package:equatable/equatable.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

/// Today's visits on the Visits screen, from `GET /api/v1/mobile/plans/today`.
sealed class VisitPlansState extends Equatable {
  const VisitPlansState();

  @override
  List<Object?> get props => const [];
}

/// First load — nothing to show yet.
final class VisitPlansLoading extends VisitPlansState {
  const VisitPlansLoading();
}

/// Today's plan, with at least one visit.
///
/// [refreshing] keeps the list on screen during a pull-to-refresh, and
/// [refreshFailure] reports a refresh that failed without discarding the list
/// the rep was already reading.
final class VisitPlansLoaded extends VisitPlansState {
  const VisitPlansLoaded(
    this.overview, {
    this.refreshing = false,
    this.refreshFailure,
  });

  final VisitPlansOverview overview;
  final bool refreshing;
  final Failure? refreshFailure;

  @override
  List<Object?> get props => [overview, refreshing, refreshFailure];
}

/// The server answered with no visits today. Distinct from a failure: the
/// request worked, there is simply nothing planned.
final class VisitPlansEmpty extends VisitPlansState {
  const VisitPlansEmpty(this.overview);

  final VisitPlansOverview overview;

  @override
  List<Object?> get props => [overview];
}

/// The first load failed; there is nothing to fall back to.
final class VisitPlansFailure extends VisitPlansState {
  const VisitPlansFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
