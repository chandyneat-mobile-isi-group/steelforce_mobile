import 'package:steelforce/core/database/drift/daos/order_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/typedefs.dart';

/// Raw CRUD over the `sync_queue` table (row maps in, row maps out — the
/// repository owns entity mapping, mirroring [QuotationLocalDataSourceImpl]).
abstract interface class SyncQueueLocalDataSource {
  Future<void> upsert(DataMap row);

  /// All queue rows joined with their quotation for display, FIFO order.
  Future<List<DataMap>> fetchAllJoined();

  /// Rows [ownerUserId] may process now: `pendingSync` whose backoff has
  /// elapsed, oldest first (FIFO).
  Future<List<DataMap>> fetchReady(String nowIso, String ownerUserId);

  /// Submitted rows of [ownerUserId] whose backend review is still open.
  Future<List<DataMap>> fetchAwaitingReview(
      String ownerUserId, List<String> openStatuses);

  Future<DataMap?> getByQuotationId(String quotationId);

  /// `status -> count`, for the pending badge.
  Future<Map<String, int>> countsByStatus();

  Future<void> deleteByQuotationId(String quotationId);
}

/// Drift-backed sync queue (**T1.5b**; Admin review columns **v24**), replacing the plaintext `catalog.db`
/// implementation.
///
/// Moving this table into the encrypted database matters more than the others:
/// queue rows carry the full quotation payload awaiting push, so until now the
/// most business-sensitive data in the app sat unencrypted the longest —
/// precisely while offline and waiting to sync.
///
/// Still the Orders-local queue, **not** ADR-006's unified engine. The
/// promotion into `core/sync/` is Phase 4 and is deliberately not attempted
/// here; doing the move first means that promotion is a refactor rather than a
/// second migration of live field data.
class SyncQueueLocalDataSourceImpl implements SyncQueueLocalDataSource {
  const SyncQueueLocalDataSourceImpl(this._dao);
  final SyncQueueDao _dao;

  @override
  Future<void> upsert(DataMap row) async {
    try {
      await _dao.upsert(row);
    } catch (e) {
      throw CacheException(message: 'Failed to write sync queue item: $e');
    }
  }

  @override
  Future<List<DataMap>> fetchAllJoined() async {
    try {
      return await _dao.fetchAllJoined();
    } catch (e) {
      throw CacheException(message: 'Failed to read sync queue: $e');
    }
  }

  @override
  Future<List<DataMap>> fetchReady(String nowIso, String ownerUserId) async {
    try {
      return await _dao.fetchReady(nowIso, ownerUserId);
    } catch (e) {
      throw CacheException(message: 'Failed to read ready sync items: $e');
    }
  }

  @override
  Future<List<DataMap>> fetchAwaitingReview(
      String ownerUserId, List<String> openStatuses) async {
    try {
      return await _dao.fetchAwaitingReview(ownerUserId, openStatuses);
    } catch (e) {
      throw CacheException(message: 'Failed to read reviewed sync items: $e');
    }
  }

  @override
  Future<DataMap?> getByQuotationId(String quotationId) async {
    try {
      return await _dao.getByQuotationId(quotationId);
    } catch (e) {
      throw CacheException(message: 'Failed to read sync item: $e');
    }
  }

  @override
  Future<Map<String, int>> countsByStatus() async {
    try {
      return await _dao.countsByStatus();
    } catch (e) {
      throw CacheException(message: 'Failed to count sync queue: $e');
    }
  }

  @override
  Future<void> deleteByQuotationId(String quotationId) async {
    try {
      await _dao.deleteByQuotationId(quotationId);
    } catch (e) {
      throw CacheException(message: 'Failed to remove sync item: $e');
    }
  }
}
