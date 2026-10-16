import 'package:steelforce/core/database/drift/daos/depot_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/features/depots/data/local/depot_drift_mappers.dart';
import 'package:steelforce/features/depots/data/local/depot_local_data_source.dart';
import 'package:steelforce/features/depots/data/models/depot_activity_model.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/models/depot_note_model.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';

/// [DepotLocalDataSource] backed by the single encrypted Drift database
/// (T2 cutover). Replaces the per-feature plaintext `depots.db`. Exceptions
/// are normalised to [CacheException] so the repository above is unaffected by
/// the storage swap.
class DepotDriftLocalDataSource implements DepotLocalDataSource {
  const DepotDriftLocalDataSource(this._dao);

  final DepotDao _dao;

  @override
  Future<List<DepotModel>> browse({
    required int page,
    required int pageSize,
    String query = '',
    DepotFilter filter = const DepotFilter(),
  }) async {
    try {
      final rows = await _dao.browse(
        page: page,
        pageSize: pageSize,
        query: query,
        territory: filter.territory,
        status: filter.status?.name,
        productCategory: filter.productCategory,
        sort: filter.sortBy.toBrowseSort(),
      );
      return rows.map((r) => r.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to browse depots: $e');
    }
  }

  @override
  Future<DepotModel?> getById(String id) async {
    try {
      final row = await _dao.getById(id);
      if (row == null) return null;
      final contacts = await _dao.fetchContacts(id);
      return row.toModel(contacts: contacts.map((c) => c.toModel()).toList());
    } catch (e) {
      throw CacheException(message: 'Failed to load depot $id: $e');
    }
  }

  @override
  Future<void> toggleFavorite(String depotId) async {
    try {
      await _dao.toggleFavorite(depotId);
    } catch (e) {
      throw CacheException(message: 'Failed to toggle favorite: $e');
    }
  }

  @override
  Future<List<DepotModel>> fetchFavorites() async {
    try {
      final rows = await _dao.fetchFavorites();
      return rows.map((r) => r.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load favorite depots: $e');
    }
  }

  @override
  Future<List<DepotModel>> fetchRecent() async {
    try {
      final rows = await _dao.fetchRecent();
      return rows.map((r) => r.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load recent depots: $e');
    }
  }

  @override
  Future<void> recordViewed(String depotId) async {
    try {
      await _dao.recordViewed(depotId);
    } catch (e) {
      throw CacheException(message: 'Failed to record viewed depot: $e');
    }
  }

  @override
  Future<List<DepotNoteModel>> fetchNotes(String depotId) async {
    try {
      final rows = await _dao.fetchNotes(depotId);
      return rows.map((r) => r.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load notes: $e');
    }
  }

  @override
  Future<void> addNote(DepotNoteModel note) async {
    try {
      await _dao.addNote(note.toCompanion());
    } catch (e) {
      throw CacheException(message: 'Failed to save note: $e');
    }
  }

  @override
  Future<List<DepotActivityModel>> fetchActivities(String depotId) async {
    try {
      final rows = await _dao.fetchActivities(depotId);
      return rows.map((r) => r.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load activities: $e');
    }
  }

  @override
  Future<void> addActivity(DepotActivityModel activity) async {
    try {
      await _dao.addActivity(activity.toCompanion());
    } catch (e) {
      throw CacheException(message: 'Failed to save activity: $e');
    }
  }

  @override
  Future<void> upsertDepots(List<DepotModel> depots) async {
    try {
      await _dao.upsertDepots(depots.map((c) => c.toRecord()).toList());
    } catch (e) {
      throw CacheException(message: 'Failed to save synced depots: $e');
    }
  }

  @override
  Future<void> markDeleted(List<String> ids) async {
    try {
      await _dao.markDeleted(ids);
    } catch (e) {
      throw CacheException(message: 'Failed to apply deletions: $e');
    }
  }

  @override
  Future<DateTime?> getLastSyncedAt(String entity) async {
    try {
      return await _dao.getLastSyncedAt(entity);
    } catch (e) {
      throw CacheException(message: 'Failed to read sync metadata: $e');
    }
  }

  @override
  Future<void> setLastSyncedAt(
    String entity,
    DateTime at, {
    String? language,
  }) async {
    try {
      await _dao.setLastSyncedAt(entity, at, language: language);
    } catch (e) {
      throw CacheException(message: 'Failed to write sync metadata: $e');
    }
  }

  @override
  Future<String?> getSyncedLanguage(String entity) async {
    try {
      return await _dao.getSyncedLanguage(entity);
    } catch (e) {
      throw CacheException(message: 'Failed to read sync metadata: $e');
    }
  }
}
