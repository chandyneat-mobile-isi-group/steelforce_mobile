import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_push_summary.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stop_discard.dart';

/// Sends visit work captured on the device, in the order it happened at the
/// shop: check-in, then the orders taken there, then check-out.
///
/// Each step is a separate request, so a day of four or five stops worked
/// offline goes out as "every check-in, every order, every check-out" rather
/// than one mixed batch.
abstract interface class VisitSyncRepository {
  /// Pushes every locally-pending visit-capture row and marks accepted rows
  /// synced: check-ins first, then whatever must reach the server before the
  /// rest of the visit (queued quotations and orders), then check-outs,
  /// stock counts, notes, photos, ....
  ///
  /// Short-circuits to a zero-count success if nothing is pending.
  ResultFuture<VisitPushSummary> pushPendingVisitData();

  /// Pushes pending check-ins only, oldest first.
  ResultFuture<VisitPushSummary> pushPendingCheckIns();

  /// Pushes everything except check-ins. A row from a stop whose check-in the
  /// server has not accepted yet is held back, so a check-out never arrives
  /// ahead of its check-in.
  ResultFuture<VisitPushSummary> pushPendingCaptures();

  /// What is still waiting to be sent, per stop. Reads the device only.
  ResultFuture<PendingVisitSync> fetchPendingVisits();

  /// Throws away everything at [stopId] the server does not have yet and
  /// resets the stop so the visit can be done again. Rows already synced are
  /// kept. Device only; cannot be undone.
  ResultFuture<VisitStopDiscard> discardPendingStop(String stopId);
}
