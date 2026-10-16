import 'package:steelforce/features/depots/data/models/depot_activity_model.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/models/depot_note_model.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';

/// Local persistence contract for the depot directory. Backed by the single
/// encrypted Drift database (see [DepotDriftLocalDataSource]); the legacy
/// plaintext `depots.db` implementation was retired in the T2 cutover.
abstract interface class DepotLocalDataSource {
  /// Returns up to `pageSize + 1` rows so the caller can detect "has more"
  /// without a separate COUNT query.
  Future<List<DepotModel>> browse({
    required int page,
    required int pageSize,
    String query,
    DepotFilter filter,
  });

  Future<DepotModel?> getById(String id);

  Future<void> toggleFavorite(String depotId);
  Future<List<DepotModel>> fetchFavorites();
  Future<List<DepotModel>> fetchRecent();
  Future<void> recordViewed(String depotId);

  Future<List<DepotNoteModel>> fetchNotes(String depotId);
  Future<void> addNote(DepotNoteModel note);

  Future<List<DepotActivityModel>> fetchActivities(String depotId);
  Future<void> addActivity(DepotActivityModel activity);

  /// Batched, transactional upsert into the depot + contact tables. The only
  /// write path that may populate `depots` — called exclusively by the sync
  /// repository.
  Future<void> upsertDepots(List<DepotModel> depots);
  Future<void> markDeleted(List<String> ids);

  Future<DateTime?> getLastSyncedAt(String entity);
  Future<void> setLastSyncedAt(String entity, DateTime at, {String? language});

  /// The `Accept-Language` tag the cached rows were fetched under.
  ///
  /// Null means "unknown" — a book synced before the language was recorded.
  /// Callers treat unknown as a match rather than forcing a resync, because a
  /// gratuitous 31-request re-page on upgrade is worse than the small chance
  /// that an old book is in the other language.
  Future<String?> getSyncedLanguage(String entity);
}
