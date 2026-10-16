import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';

/// What came of asking for a depot to be added to today.
///
/// Three outcomes, not two, because "the depot is already on their day" and
/// "the request has not reached the server yet" are both **successes** from the
/// rep's point of view and neither should be dressed as a red error
/// (`docs/feature/my-visits/ad-hoc-visits-mobile.md` §7, §8). Only a genuine
/// business rejection comes back as a `Failed`.
sealed class AdHocVisitOutcome extends Equatable {
  const AdHocVisitOutcome();

  @override
  List<Object?> get props => [];
}

/// The server issued the visit. Covers `created: false` too — a replay of an
/// earlier attempt with the same `clientRequestId` returns the original visit,
/// which is exactly what idempotency is for and is success, not a duplicate.
final class AdHocVisitAdded extends AdHocVisitOutcome {
  const AdHocVisitAdded({
    required this.stop,
    required this.depot,
    required this.visitDate,
    required this.created,
  });

  /// An ordinary [RouteStop], already upserted locally. It carries
  /// `visitSource: adHoc`, a `sequence` in the 1001+ band, and no planned
  /// window.
  final RouteStop stop;

  /// The full stop-info record, sent because an unplanned depot may not be in
  /// the device's current route payload at all.
  final DepotStopInfo depot;

  final DateTime visitDate;

  /// False when the server replayed an earlier attempt rather than creating
  /// anything. Still a success — do not warn about it.
  final bool created;

  @override
  List<Object?> get props => [stop, depot, visitDate, created];
}

/// The depot is already on today — either the Call Plan issued it, or the rep
/// already added it (the two 409s).
///
/// **Not an error toast.** The depot is on their day either way, so the right
/// response is to take them to the card they already have.
final class AdHocVisitAlreadyOnToday extends AdHocVisitOutcome {
  const AdHocVisitAlreadyOnToday({required this.depotId, required this.code});

  final String depotId;

  /// Which of the two 409s it was, kept only so the copy can differ; both are
  /// handled the same way.
  final String code;

  @override
  List<Object?> get props => [depotId, code];
}

/// The request could not reach the server and is now queued under a persisted
/// `clientRequestId`, to be retried as itself.
///
/// The rep sees a pending row — "Adding Toul Kork Yard…" — and **not** an
/// optimistic card: there is no stop id yet, so a card they could tap would do
/// nothing, which is worse than showing the wait honestly.
final class AdHocVisitQueued extends AdHocVisitOutcome {
  const AdHocVisitQueued({
    required this.clientRequestId,
    required this.depotId,
    required this.depotName,
  });

  final String clientRequestId;
  final String depotId;
  final String depotName;

  @override
  List<Object?> get props => [clientRequestId, depotId, depotName];
}
