import 'dart:async';

import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_visit_outcome.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';

/// Ad hoc visits during a practice lesson: never sent.
///
/// The real operation creates a visit on the server, so it is the one call in
/// the dashboard that cannot be rehearsed honestly against it. Here:
///
/// * the demo depot is already on today's practice route, which is exactly
///   what the server would answer ([AdHocVisitAlreadyOnToday]);
/// * any other depot is held as a pending request in memory — the same
///   "waiting to send" row the rep sees offline — and is discarded with the
///   lesson;
/// * draining sends nothing; the real outbox is left untouched for after.
///
/// Once [PracticeWorld.isClosed], every call goes to the real repository.
class PracticeAdHocVisitRepository implements AdHocVisitRepository {
  PracticeAdHocVisitRepository(this._real, this._world) {
    _world.onClose(() async => _changes.close());
  }

  final AdHocVisitRepository _real;
  final PracticeWorld _world;

  final List<PendingAdHocVisit> _pending = [];
  final StreamController<List<PendingAdHocVisit>> _changes =
      StreamController<List<PendingAdHocVisit>>.broadcast();
  int _sequence = 0;

  bool get _live => !_world.isClosed;

  @override
  ResultFuture<AdHocVisitOutcome> add({
    required String depotId,
    required String sk,
    required String depotName,
  }) async {
    if (!_live) {
      return _real.add(depotId: depotId, sk: sk, depotName: depotName);
    }
    if (depotId == PracticeIds.depotId) {
      return Success(AdHocVisitAlreadyOnToday(depotId: depotId, code: sk));
    }
    final request = PendingAdHocVisit(
      clientRequestId: 'practice-ad-hoc-${++_sequence}',
      depotId: depotId,
      depotName: depotName,
      createdAt: DateTime.now(),
    );
    _pending.add(request);
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_pending));
    return Success(AdHocVisitQueued(
      clientRequestId: request.clientRequestId,
      depotId: depotId,
      depotName: depotName,
    ));
  }

  @override
  ResultFuture<List<AdHocVisitOutcome>> drainQueue() async {
    if (!_live) return _real.drainQueue();
    return const Success([]);
  }

  @override
  ResultFuture<Set<String>> depotIdsOnDay(DateTime day) async {
    if (!_live) return _real.depotIdsOnDay(day);
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    return Success(isToday ? {PracticeIds.depotId} : <String>{});
  }

  @override
  Stream<List<PendingAdHocVisit>> watchPending() {
    if (!_live) return _real.watchPending();
    return Stream.multi((controller) {
      controller.add(List.unmodifiable(_pending));
      final sub = _changes.stream.listen(
        controller.add,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }
}
