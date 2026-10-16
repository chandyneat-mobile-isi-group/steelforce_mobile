/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
///
/// [VisitSyncRemoteDataSource] for a demo build: `POST /mobile/visits/push`
/// answered from [DemoVisitLedger], so a day's offline work drains when the
/// demo is switched back online.
///
/// Lenient like the real `/push` (`check-in-check-out-mobile.md` §9): a row
/// that conflicts with the server's copy is accepted and the server's copy
/// kept; only a row for a stop the demo never issued is discarded, with the
/// same `Visit.StopNotFound` the server gives.
///
/// **One deliberate difference: photos are accepted.** Live, they stay
/// pending until an upload path exists (OPEN-1, `VisitPushBatch.photosAreBlocked`).
/// In a demo that would leave every proof photo stuck in the Sync Center, and
/// the drain could never be shown finishing.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_result.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';

class DemoVisitSyncRemoteDataSource implements VisitSyncRemoteDataSource {
  const DemoVisitSyncRemoteDataSource(this._network, this._ledger);

  final DemoNetwork _network;
  final DemoVisitLedger _ledger;

  @override
  Future<VisitPushResult> pushVisitData(VisitPushBatch batch) async {
    await _network.roundTrip();

    final accepted = <String>[];
    final discarded = <String>[];

    // Check-ins before check-outs, the order the server applies them in.
    for (final r in batch.checkIns) {
      if (_accept(r.id, r.stopId, accepted, discarded)) {
        _ledger.checkIn(
          id: r.id,
          stopId: r.stopId,
          timestamp: r.timestamp,
          overrideReason: r.overrideReason,
          isMocked: r.isMocked,
          strict: false,
        );
      }
    }
    for (final r in batch.checkOuts) {
      if (_accept(r.id, r.stopId, accepted, discarded)) {
        _ledger.checkOut(
          id: r.id,
          stopId: r.stopId,
          timestamp: r.timestamp,
          durationMinutes: r.durationMinutes,
          checkInId: r.checkInId,
          outcome: r.outcome?.name,
          noOrderReason: r.noOrderReason,
          strict: false,
        );
      }
    }
    final captures = <({String id, String? stopId})>[
      for (final r in batch.orderLines) (id: r.id, stopId: r.stopId),
      for (final r in batch.stockUpdates) (id: r.id, stopId: r.stopId),
      for (final r in batch.returns) (id: r.id, stopId: r.stopId),
      for (final r in batch.collections) (id: r.id, stopId: r.stopId),
      for (final r in batch.notes) (id: r.id, stopId: r.stopId),
      for (final r in batch.photos) (id: r.id, stopId: r.stopId),
    ];
    for (final c in captures) {
      _accept(c.id, c.stopId, accepted, discarded);
    }

    _ledger.rememberPushed(accepted);
    return VisitPushResult(
      acceptedIds: accepted,
      rejectedIds: const [],
      discardedIds: discarded,
      discardReasons: {
        for (final id in discarded) id: VisitErrorCodes.stopNotFound,
      },
      syncedAt: _ledger.now().toUtc(),
    );
  }

  /// Sorts [id] into [accepted] or [discarded]; true when accepted.
  ///
  /// A row with no stop (a depot stock count taken outside a visit) has no
  /// stop to be missing, so it is accepted.
  bool _accept(String id, String? stopId, List<String> accepted,
      List<String> discarded) {
    if (stopId == null || _ledger.isKnownStop(stopId)) {
      accepted.add(id);
      return true;
    }
    discarded.add(id);
    return false;
  }
}
