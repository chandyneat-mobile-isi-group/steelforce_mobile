import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_push_summary.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stop_discard.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';

/// The visit push, as practice screens reach it.
///
/// Practice records never enter the real queue (they stay in
/// `PracticeVisitRepository`), so there is nothing of the lesson's to send.
/// The pushes the practice flow triggers — "Complete visit" fires one, the
/// dashboard's pull fires another — therefore send nothing and report zero,
/// rather than reaching for the real queue on the rep's behalf mid-lesson.
/// The real queue is left exactly as it was; the sync engine (built outside
/// the practice scope) keeps draining it on its own schedule.
///
/// Reads of what is waiting are the real ones: they describe real work. A
/// discard naming a real stop is a real action and goes to the real
/// repository; one naming the practice stop has nothing to discard.
///
/// Once [PracticeWorld.isClosed], every call goes to the real repository.
class PracticeVisitSyncRepository implements VisitSyncRepository {
  PracticeVisitSyncRepository(this._real, this._world);

  final VisitSyncRepository _real;
  final PracticeWorld _world;

  bool get _live => !_world.isClosed;

  Result<VisitPushSummary> get _nothingSent =>
      Success(VisitPushSummary(pushedCount: 0, syncedAt: DateTime.now()));

  @override
  ResultFuture<VisitPushSummary> pushPendingVisitData() async {
    if (!_live) return _real.pushPendingVisitData();
    return _nothingSent;
  }

  @override
  ResultFuture<VisitPushSummary> pushPendingCheckIns() async {
    if (!_live) return _real.pushPendingCheckIns();
    return _nothingSent;
  }

  @override
  ResultFuture<VisitPushSummary> pushPendingCaptures() async {
    if (!_live) return _real.pushPendingCaptures();
    return _nothingSent;
  }

  @override
  ResultFuture<PendingVisitSync> fetchPendingVisits() =>
      _real.fetchPendingVisits();

  @override
  ResultFuture<VisitStopDiscard> discardPendingStop(String stopId) async {
    if (!_live || !PracticeIds.isPractice(stopId)) {
      return _real.discardPendingStop(stopId);
    }
    return Success(VisitStopDiscard(
      stopId: stopId,
      discardedRecords: 0,
      reset: VisitStopReset.unchanged,
    ));
  }
}
