import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_visit_outcome.dart';

/// Adding a depot the Call Plan missed to today.
abstract interface class AdHocVisitRepository {
  /// Requests the visit, persisting the request first so a retry replays it.
  ///
  /// [sk] is the depot's SAP code, which is what the server is keyed on.
  /// [depotId] is never sent — it is kept so a 409 can route the rep to the
  /// stop they already have. [depotName] is carried only so a queued request
  /// can name the shop while it waits; it is never sent either.
  ///
  /// Succeeds with [AdHocVisitAdded] when the server issued the stop,
  /// [AdHocVisitAlreadyOnToday] when the depot was on the day already, and
  /// [AdHocVisitQueued] when the request could not be delivered. Fails only on
  /// a business refusal that retrying cannot fix.
  ResultFuture<AdHocVisitOutcome> add({
    required String depotId,
    required String sk,
    required String depotName,
  });

  /// Retries every queued request, oldest first, reusing its stored id.
  ///
  /// Safe to call repeatedly and safe to drain twice: the same
  /// `clientRequestId` makes the server return the original visit with
  /// `created: false`, which is treated as success.
  ///
  /// Returns the requests that reached the server, so the caller knows whether
  /// a route refresh is worth triggering.
  ResultFuture<List<AdHocVisitOutcome>> drainQueue();

  /// The depot ids already on [day], whichever source put them there. Feeds
  /// the picker, so a rep is not offered a shop whose only possible answer is
  /// "already on today's route".
  ResultFuture<Set<String>> depotIdsOnDay(DateTime day);

  /// Requests still waiting to reach the server. The dashboard renders these
  /// as pending rows — never as tappable cards, because they have no stop id.
  Stream<List<PendingAdHocVisit>> watchPending();
}

/// A queued request, as the UI needs to show it.
class PendingAdHocVisit {
  const PendingAdHocVisit({
    required this.clientRequestId,
    required this.depotId,
    required this.depotName,
    required this.createdAt,
    this.lastErrorCode,
  });

  final String clientRequestId;
  final String depotId;
  final String depotName;
  final DateTime createdAt;

  /// The last refusal code seen, if any. Present only for codes worth
  /// retrying — a business rejection removes the row instead.
  final String? lastErrorCode;
}
