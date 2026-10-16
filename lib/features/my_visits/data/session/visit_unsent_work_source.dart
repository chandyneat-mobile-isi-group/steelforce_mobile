import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/features/my_visits/data/local/visit_local_data_source.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';

/// How a visit starts on the server: ad hoc visit requests waiting in the
/// outbox, then check-ins still `dirty`.
///
/// Registered ahead of quotations, and [VisitUnsentWorkSource] after them, so
/// each stop reaches the server as check-in → orders → check-out.
class VisitCheckInUnsentWorkSource
    implements UnsentWorkSource, UnsentWorkBreakdown {
  const VisitCheckInUnsentWorkSource({
    required VisitLocalDataSource visits,
    required VisitSyncRepository visitSync,
    required AdHocVisitRepository adHoc,
  })  : _visits = visits,
        _visitSync = visitSync,
        _adHoc = adHoc;

  static const name = 'my_visits.check_ins';

  final VisitLocalDataSource _visits;
  final VisitSyncRepository _visitSync;
  final AdHocVisitRepository _adHoc;

  @override
  String get debugName => name;

  @override
  Future<int> countUnsent() async {
    final checkIns = await _visits.countPendingCheckIns();
    final adHoc = await _adHoc.watchPending().first;
    return checkIns + adHoc.length;
  }

  /// Every pending check-in and ad hoc request is retried automatically.
  @override
  Future<int> countSendable() => countUnsent();

  /// Ad hoc requests first: a visit the server has not created yet is what
  /// the check-in at that stop hangs off.
  @override
  Future<void> sendNow() async {
    await _adHoc.drainQueue();
    await _visitSync.pushPendingCheckIns();
  }

  @override
  Future<List<UnsentWorkCount>> breakdown() async => [
        UnsentWorkCount(UnsentWorkKind.adHocVisits,
            (await _adHoc.watchPending().first).length),
        UnsentWorkCount(
            UnsentWorkKind.checkIns, await _visits.countPendingCheckIns()),
      ];
}

/// The rest of a visit the server does not have yet: check-outs, order lines,
/// stock counts, returns, collections, notes and photos still `dirty`.
class VisitUnsentWorkSource implements UnsentWorkSource, UnsentWorkBreakdown {
  const VisitUnsentWorkSource({
    required VisitLocalDataSource visits,
    required VisitSyncRepository visitSync,
  })  : _visits = visits,
        _visitSync = visitSync;

  static const name = 'my_visits';

  final VisitLocalDataSource _visits;
  final VisitSyncRepository _visitSync;

  @override
  String get debugName => name;

  @override
  Future<int> countUnsent() async {
    final all = await _visits.countPendingVisitRecords();
    final checkIns = await _visits.countPendingCheckIns();
    return all - checkIns;
  }

  /// Includes rows waiting on their stop's check-in: they go out as soon as
  /// that check-in does, without the rep doing anything.
  @override
  Future<int> countSendable() => countUnsent();

  /// Captures only. The engine has already run every source registered
  /// before this one — check-ins, then quotations — in this same pass.
  @override
  Future<void> sendNow() => _visitSync.pushPendingCaptures();

  @override
  Future<List<UnsentWorkCount>> breakdown() async {
    final checkOuts = await _visits.countPendingCheckOuts();
    return [
      UnsentWorkCount(UnsentWorkKind.checkOuts, checkOuts),
      UnsentWorkCount(
          UnsentWorkKind.visitRecords, await countUnsent() - checkOuts),
    ];
  }
}
