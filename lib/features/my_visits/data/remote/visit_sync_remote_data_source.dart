import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_result.dart';

/// Push endpoint for locally-captured visit data (check-ins, check-outs,
/// stock counts, notes, photos, ...) — the outbound mirror of
/// [RouteRemoteDataSource]'s pull side.
///
/// One implementation: [ApiVisitSyncRemoteDataSource], posting the batch to
/// `POST /api/v1/mobile/visits/push`. The mock that stood here accepted every
/// row unconditionally — the one behaviour a push endpoint must never be
/// assumed to have, since it hid the rejected/pending handling this feature
/// depends on.
///
/// Implementations return an accepted/rejected id split rather than a
/// whole-batch verdict, and throw only when the *request* failed. One bad row
/// must never strand a day's other captures on the device
/// (`docs/feature/my-visits/api.md` §3.3).
abstract interface class VisitSyncRemoteDataSource {
  Future<VisitPushResult> pushVisitData(VisitPushBatch batch);
}
