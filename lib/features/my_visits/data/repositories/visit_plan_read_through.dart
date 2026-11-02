part of 'visit_plan_repository_impl.dart';

/// The server's answer, else this device's copy of its last one while it
/// still describes the period asked for.
extension _ReadThrough on VisitPlanRepositoryImpl {
  ResultFuture<VisitPlansOverview> _readThrough(
    String key,
    Future<VisitPlansOverview> Function() fetch, {
    required bool Function(DateTime savedAt, DateTime now) stillValid,
  }) async {
    final live = await _guard(fetch);
    final local = _local;
    if (local == null) return live;
    switch (live) {
      case Success(:final data):
        try {
          await local.save(key, data, _now());
        } on Object {
          // The copy is a convenience; failing to keep it must not cost the
          // rep the answer they already have.
        }
        return live;
      case Failed(:final failure)
          when failure is NetworkFailure || failure is ServerUnreachableFailure:
        final saved = await local.read(key);
        final at = saved?.savedAt;
        if (saved != null && at != null && stillValid(at, _now())) {
          return Success(saved);
        }
        return live;
      case Failed():
        return live;
    }
  }
}
