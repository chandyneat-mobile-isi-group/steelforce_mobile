import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/visit_api_mapper.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_result.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';

/// `POST /api/v1/mobile/visits/push` — the real thing.
///
/// The sole implementation of [VisitSyncRemoteDataSource]. It replaced a mock
/// behind the same interface, so `VisitSyncRepositoryImpl` — which already
/// implements the pending-queue and partial-acceptance handling — was
/// untouched by the cutover.
///
/// The whole device drains in one round trip (`docs/feature/my-visits/api.md` §6):
/// a rep back in signal sends every pending row of every kind at once, not
/// eight requests. The response is an accepted/rejected id split, never a
/// whole-batch verdict.
class ApiVisitSyncRemoteDataSource implements VisitSyncRemoteDataSource {
  const ApiVisitSyncRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<VisitPushResult> pushVisitData(VisitPushBatch batch) async {
    // Nothing the endpoint can take. The caller already skips a fully empty
    // batch, but a batch of *only* photos passes that check and is still
    // un-pushable while OPEN-1 is unresolved (see [VisitPushBatchApiJson]).
    // Posting eight empty arrays would spend a request to be told nothing.
    //
    // Reporting zero accepted — rather than throwing — is what keeps those
    // photos pending instead of surfacing as a sync failure the rep can do
    // nothing about.
    if (batch.hasNothingSendable) {
      return VisitPushResult(
          acceptedIds: const [],
          rejectedIds: batch.photosAreBlocked,
          syncedAt: DateTime.now());
    }

    final DataMap data;
    try {
      final res = await _client.post<DataMap>(
        ApiEndpoints.visitPushEndpoint,
        data: batch.toPushJson(),
      );
      data = ApiEnvelope.fromBody(res.data).data;
    } on DioException catch (e) {
      // Every pending row stays pending: the repository only marks rows synced
      // from `acceptedIds`, and a throw never produces any. Re-posting the same
      // batch later is safe because the backend is required to be idempotent
      // on the client-generated row ids (§3.2) — which is what makes the retry
      // free of duplicates rather than merely unlikely to produce them.
      throw ApiException(ApiError.fromDio(e));
    }

    return VisitPushResult(
      acceptedIds: _ids(data['acceptedIds']),
      // Held pending and retried later. Ids the client sent that come back in
      // neither list are treated as rejected too — and that falls out for free,
      // because only ids present in `acceptedIds` are ever marked synced.
      rejectedIds: [..._ids(data['rejectedIds']), ...batch.photosAreBlocked],
      // OPEN-2, now resolved server-side (api.md §6.1). Absent from older
      // responses, which `_ids` degrades to an empty list — so this reads
      // correctly against a backend that has not deployed the bucket yet.
      discardedIds: _ids(data['discardedIds']),
      discardReasons: _discardReasons(data['discarded']),
      // The server's own receipt time when it sends one. Falling back to the
      // device clock only affects the "last synced" label; it is never written
      // back over a capture's own timestamp (§8.4).
      syncedAt: parseUtc(data['syncedAt']) ?? DateTime.now(),
    );
  }

  /// Reads an id array defensively.
  ///
  /// A malformed or missing `acceptedIds` must degrade to "nothing was
  /// accepted", never to a crash: the rows are already durable on the device,
  /// and the correct response to an unreadable answer is to keep them pending
  /// and retry, not to take down the sync. Hence a type *check* rather than a
  /// cast — a cast would throw on the very shape this exists to absorb.
  static List<String> _ids(Object? raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];

  /// Reads `discarded: [{ id, errorCode, reason }]` into `id → errorCode`.
  ///
  /// Same defensiveness as [_ids], and for a sharper reason: this map only
  /// feeds a log line. An unreadable entry must cost that log line and nothing
  /// else — never the push, and never the `discardedIds` list beside it, which
  /// is what actually stops the row cycling.
  static Map<String, String> _discardReasons(Object? raw) {
    if (raw is! List) return const {};
    final out = <String, String>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final id = entry['id'];
      if (id is! String) continue;
      final code = entry['errorCode'];
      out[id] = code is String ? code : 'unknown';
    }
    return out;
  }
}
