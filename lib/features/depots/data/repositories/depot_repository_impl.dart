import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/local/depot_local_data_source.dart';
import 'package:steelforce/features/depots/data/models/depot_activity_model.dart';
import 'package:steelforce/features/depots/data/models/depot_note_model.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/entities/depot_note.dart';
import 'package:steelforce/features/depots/domain/entities/depot_paged_result.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';

/// Local-read only. Network-backed creation and sync live in the sync repository.
class DepotRepositoryImpl implements DepotRepository {
  const DepotRepositoryImpl(this._local);
  final DepotLocalDataSource _local;

  @override
  ResultFuture<DepotPagedResult> browse({
    required int page,
    required int pageSize,
    String query = '',
    DepotFilter filter = const DepotFilter(),
  }) async {
    try {
      final rows = await _local.browse(
        page: page,
        pageSize: pageSize,
        query: query,
        filter: filter,
      );
      final hasMore = rows.length > pageSize;
      return Success(
        DepotPagedResult(
          items: hasMore ? rows.sublist(0, pageSize) : rows,
          page: page,
          hasMore: hasMore,
        ),
      );
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Depot> getById(String id) async {
    try {
      final depot = await _local.getById(id);
      return depot == null
          ? const Failed(CacheFailure(message: 'Depot not found.'))
          : Success(depot);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> toggleFavorite(String depotId) async {
    try {
      await _local.toggleFavorite(depotId);
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Depot>> fetchFavorites() async {
    try {
      return Success(await _local.fetchFavorites());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Depot>> fetchRecent() async {
    try {
      return Success(await _local.fetchRecent());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> recordViewed(String depotId) async {
    try {
      await _local.recordViewed(depotId);
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<DepotNote>> fetchNotes(String depotId) async {
    try {
      return Success(await _local.fetchNotes(depotId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addNote(String depotId, String body) async {
    try {
      await _local.addNote(
        DepotNoteModel(
          id: '$depotId-NOTE-${DateTime.now().microsecondsSinceEpoch}',
          depotId: depotId,
          body: body,
          createdAt: DateTime.now(),
        ),
      );
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<DepotActivity>> fetchActivities(String depotId) async {
    try {
      return Success(await _local.fetchActivities(depotId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addActivity(DepotActivity activity) async {
    try {
      await _local.addActivity(
        DepotActivityModel(
          id: activity.id,
          depotId: activity.depotId,
          type: activity.type,
          summary: activity.summary,
          createdAt: activity.createdAt,
        ),
      );
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }
}
