import 'package:steelforce/core/database/drift/daos/visit_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_mappers.dart';
import 'package:steelforce/features/my_visits/data/local/visit_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// [VisitLocalDataSource] backed by the single encrypted Drift database
/// (T1.5 cutover). Replaces the plaintext `routes.db` implementation.
///
/// This datasource holds the most valuable data in the app: a capture that never
/// reaches SAP is a lost order or an uncollected payment. The interface is
/// unchanged so the repository above is untouched (ADR-003 seam), and every
/// failure is normalised to [CacheException] exactly as before
/// (`docs/skills/engineering-standard.md` §7 — no raw storage exception reaches the
/// repository).
class VisitDriftLocalDataSource implements VisitLocalDataSource {
  const VisitDriftLocalDataSource(this._dao, this._logger);

  final VisitDao _dao;
  final AppLogger _logger;

  /// Wraps a write so a storage failure can never surface as a raw
  /// `SqliteException` — most often an FK rejection when the stop is unknown.
  Future<void> _write(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      throw CacheException(message: 'Failed to store $what: $e');
    }
  }

  Future<List<T>> _read<T>(
      String what, Future<List<T>> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw CacheException(message: 'Failed to load $what: $e');
    }
  }

  // ── Check-in / check-out ────────────────────────────────────────────

  @override
  Future<void> insertCheckIn(CheckInRecordModel record) =>
      _write('check-in', () => _dao.upsertCheckIn(record.toCompanion()));

  @override
  Future<void> insertCheckOut(CheckOutRecordModel record) =>
      _write('check-out', () => _dao.upsertCheckOut(record.toCompanion()));

  // ── Captures: insert ────────────────────────────────────────────────

  @override
  Future<void> insertOrderLine(VisitOrderLineModel line) =>
      _write('order line', () => _dao.insertOrderLine(line.toCompanion()));

  @override
  Future<void> insertStockUpdate(VisitStockUpdateModel update) => _write(
      'stock update', () => _dao.insertStockUpdate(update.toCompanion()));

  @override
  Future<void> insertReturn(VisitReturnModel returnItem) =>
      _write('return', () => _dao.insertReturn(returnItem.toCompanion()));

  @override
  Future<void> insertCollection(VisitCollectionModel collection) => _write(
      'collection', () => _dao.insertCollection(collection.toCompanion()));

  @override
  Future<void> insertNote(VisitNoteModel note) =>
      _write('note', () => _dao.insertNote(note.toCompanion()));

  @override
  Future<void> insertPhoto(VisitPhotoModel photo) =>
      _write('photo', () => _dao.insertPhoto(photo.toCompanion()));

  // ── Captures: read by stop ──────────────────────────────────────────

  @override
  Future<List<VisitOrderLineModel>> fetchOrderLines(String stopId) => _read(
      'order lines',
      () async => (await _dao.fetchOrderLines(stopId))
          .map((r) => r.toModel())
          .toList());

  @override
  Future<List<VisitStockUpdateModel>> fetchStockUpdates(String stopId) => _read(
      'stock updates',
      () async => (await _dao.fetchStockUpdates(stopId))
          .map((r) => r.toModel())
          .toList());

  @override
  Future<List<VisitReturnModel>> fetchReturns(String stopId) => _read(
      'returns',
      () async =>
          (await _dao.fetchReturns(stopId)).map((r) => r.toModel()).toList());

  @override
  Future<List<VisitCollectionModel>> fetchCollections(String stopId) => _read(
      'collections',
      () async => (await _dao.fetchCollections(stopId))
          .map((r) => r.toModel())
          .toList());

  @override
  Future<List<VisitNoteModel>> fetchNotes(String stopId) => _read(
      'notes',
      () async =>
          (await _dao.fetchNotes(stopId)).map((r) => r.toModel()).toList());

  @override
  Future<List<VisitPhotoModel>> fetchPhotos(String stopId) => _read(
      'photos',
      () async =>
          (await _dao.fetchPhotos(stopId)).map((r) => r.toModel()).toList());

  // ── Push batch: pending rows ────────────────────────────────────────

  @override
  Future<List<CheckInRecordModel>> fetchPendingCheckIns() => _read(
      'pending check-ins',
      () async =>
          (await _dao.fetchPendingCheckIns()).map((r) => r.toModel()).toList());

  @override
  Future<List<CheckOutRecordModel>> fetchPendingCheckOuts() => _read(
      'pending check-outs',
      () async => (await _dao.fetchPendingCheckOuts())
          .map((r) => r.toModel())
          .toList());

  @override
  Future<List<VisitOrderLineModel>> fetchPendingOrderLines() => _read(
      'pending order lines',
      () async => (await _dao.fetchPendingOrderLines())
          .map((r) => r.toModel())
          .toList());

  @override
  Future<List<VisitStockUpdateModel>> fetchPendingStockUpdates() => _read(
      'pending stock updates',
      () async => (await _dao.fetchPendingStockUpdates())
          .map((r) => r.toModel())
          .toList());

  @override
  Future<List<VisitReturnModel>> fetchPendingReturns() => _read(
      'pending returns',
      () async =>
          (await _dao.fetchPendingReturns()).map((r) => r.toModel()).toList());

  @override
  Future<List<VisitCollectionModel>> fetchPendingCollections() => _read(
      'pending collections',
      () async => (await _dao.fetchPendingCollections())
          .map((r) => r.toModel())
          .toList());

  @override
  Future<List<VisitNoteModel>> fetchPendingNotes() => _read(
      'pending notes',
      () async =>
          (await _dao.fetchPendingNotes()).map((r) => r.toModel()).toList());

  @override
  Future<List<VisitPhotoModel>> fetchPendingPhotos() => _read(
      'pending photos',
      () async =>
          (await _dao.fetchPendingPhotos()).map((r) => r.toModel()).toList());

  // ── Post-push bookkeeping ───────────────────────────────────────────

  /// Translates the sync repository's legacy table-name string onto the typed
  /// [VisitCaptureTable] the DAO requires.
  ///
  /// An unknown name is **loud, not silent**: the legacy implementation would
  /// have issued an UPDATE against a non-existent table and quietly affected
  /// nothing, leaving those rows `dirty` and re-pushed forever. Here it throws,
  /// because "the server accepted these rows and we failed to record it" is a
  /// data-integrity bug, not a no-op.
  @override
  Future<void> markSynced({
    required String table,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return;
    final target = visitCaptureTableFromLegacyName(table);
    if (target == null) {
      _logger.error('visit_sync.unknown_table', fields: {'table': table});
      throw CacheException(message: 'Unknown visit capture table: $table');
    }
    await _write('sync state', () => _dao.markSynced(target, ids));
  }

  @override
  Future<int> countPendingVisitRecords() async {
    try {
      return await _dao.countPendingVisitRecords();
    } catch (e) {
      throw CacheException(
          message: 'Failed to count pending visit records: $e');
    }
  }

  @override
  Future<int> countPendingCheckIns() async {
    try {
      return await _dao.countPendingCheckIns();
    } catch (e) {
      throw CacheException(message: 'Failed to count pending check-ins: $e');
    }
  }

  @override
  Future<int> countPendingCheckOuts() async {
    try {
      return await _dao.countPendingCheckOuts();
    } catch (e) {
      throw CacheException(message: 'Failed to count pending check-outs: $e');
    }
  }

  @override
  Future<Map<String, ({String name, String nameKh})>> fetchShopNamesForStops(
      Set<String> stopIds) async {
    try {
      return await _dao.fetchShopNamesForStops(stopIds);
    } catch (e) {
      throw CacheException(message: 'Failed to read shop names: $e');
    }
  }

  @override
  Future<CheckInRecordModel?> checkInForStop(String stopId) async {
    try {
      return (await _dao.checkInForStop(stopId))?.toModel();
    } catch (e) {
      throw CacheException(message: 'Failed to read check-in: $e');
    }
  }

  @override
  Future<void> adoptServerCheckIn(String localId, String serverId) => _write(
      'adopted check-in', () => _dao.adoptServerCheckIn(localId, serverId));

  @override
  Future<void> deleteCheckIn(String id) =>
      _write('check-in delete', () => _dao.deleteCheckIn(id));

  @override
  Future<void> deleteCheckOut(String id) =>
      _write('check-out delete', () => _dao.deleteCheckOut(id));

  @override
  Future<DiscardedStopWork> discardUnsentStopWork(String stopId) async {
    try {
      return await _dao.discardUnsentStopWork(
        stopId,
        // The stored status is the domain enum's name (`route_drift_mappers`).
        notVisitedStatus: VisitStatus.pending.name,
        checkedInStatus: VisitStatus.checkedIn.name,
      );
    } catch (e) {
      throw CacheException(message: 'Failed to discard unsent visit: $e');
    }
  }
}
