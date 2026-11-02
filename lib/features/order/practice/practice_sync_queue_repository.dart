import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/domain/repositories/sync_queue_repository.dart';

/// The outbound quotation queue as practice sees it: always empty, and every
/// write a no-op.
///
/// Practice work is never sent anywhere, so there is nothing to queue — and a
/// practice id reaching the real `sync_queue` table would be a row the real
/// `SyncQueueProcessor` tries to push to the backend. Swallowing the write
/// here is what makes that impossible. Once [PracticeWorld.isClosed] every
/// call goes to [_real].
class PracticeSyncQueueRepository implements SyncQueueRepository {
  PracticeSyncQueueRepository({
    required SyncQueueRepository real,
    required PracticeWorld world,
  })  : _real = real,
        _world = world;

  final SyncQueueRepository _real;
  final PracticeWorld _world;

  bool get _live => _world.isClosed;

  @override
  Stream<List<SyncQueueItem>> watchQueue() =>
      _live ? _real.watchQueue() : Stream.value(const <SyncQueueItem>[]);

  @override
  Future<void> enqueue(String quotationId, {String? ownerUserId}) async {
    if (_live) return _real.enqueue(quotationId, ownerUserId: ownerUserId);
  }

  @override
  Future<List<SyncQueueItem>> readyItems(String ownerUserId) async {
    if (_live) return _real.readyItems(ownerUserId);
    return const <SyncQueueItem>[];
  }

  @override
  Future<List<SyncQueueItem>> awaitingReview(String ownerUserId) async {
    if (_live) return _real.awaitingReview(ownerUserId);
    return const <SyncQueueItem>[];
  }

  @override
  Future<void> save(SyncQueueItem item) async {
    if (_live) return _real.save(item);
  }

  @override
  Future<SyncQueueCounts> counts() async {
    if (_live) return _real.counts();
    return const SyncQueueCounts();
  }

  @override
  Future<void> remove(String quotationId) async {
    if (_live) return _real.remove(quotationId);
  }
}
