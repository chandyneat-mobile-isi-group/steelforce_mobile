import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/entities/depot_note.dart';
import 'package:steelforce/features/depots/domain/entities/depot_paged_result.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';
import 'package:steelforce/features/depots/practice/practice_depot_store.dart';

/// [DepotRepository] for a practice run: the directory is the practice store,
/// and every write — favourite, recently viewed, note, activity — lands in
/// memory, never in the encrypted database.
///
/// The list shows **only** practice depots, so a lesson never mixes demo
/// shops with the rep's real book. A detail read of a real id (reached from
/// another feature's practice data) is still answered by the real repository,
/// read-only; anything written against it stays in memory.
///
/// Once [PracticeWorld.isClosed], every call goes to [_real] — a stand-in that
/// a base-scope singleton captured degrades to real behaviour, never to demo
/// data.
class PracticeDepotRepository implements DepotRepository {
  PracticeDepotRepository({
    required DepotRepository real,
    required PracticeWorld world,
    required PracticeDepotStore store,
  })  : _real = real,
        _world = world,
        _store = store;

  final DepotRepository _real;
  final PracticeWorld _world;
  final PracticeDepotStore _store;

  bool get _live => !_world.isClosed;

  @override
  ResultFuture<DepotPagedResult> browse({
    required int page,
    required int pageSize,
    String query = '',
    DepotFilter filter = const DepotFilter(),
  }) async {
    if (!_live) {
      return _real.browse(
        page: page,
        pageSize: pageSize,
        query: query,
        filter: filter,
      );
    }
    final matches = _store.depots
        .where((d) => _matchesQuery(d, query) && _matchesFilter(d, filter))
        .toList(growable: false);
    final start = (page * pageSize).clamp(0, matches.length);
    final end = (start + pageSize).clamp(0, matches.length);
    return Success(
      DepotPagedResult(
        items: matches.sublist(start, end),
        page: page,
        hasMore: end < matches.length,
      ),
    );
  }

  @override
  ResultFuture<Depot> getById(String id) async {
    if (!_live || !PracticeIds.isPractice(id)) return _real.getById(id);
    final depot = _store.byId(id) ?? _store.byId(PracticeIds.depotId)!;
    return Success(depot);
  }

  @override
  ResultFuture<void> toggleFavorite(String depotId) async {
    if (!_live) return _real.toggleFavorite(depotId);
    _store.toggleFavorite(depotId);
    return const Success(null);
  }

  @override
  ResultFuture<List<Depot>> fetchFavorites() async {
    if (!_live) return _real.fetchFavorites();
    return Success(_store.favorites);
  }

  @override
  ResultFuture<List<Depot>> fetchRecent() async {
    if (!_live) return _real.fetchRecent();
    return Success(_store.recent);
  }

  @override
  ResultFuture<void> recordViewed(String depotId) async {
    if (!_live) return _real.recordViewed(depotId);
    _store.recordViewed(depotId);
    return const Success(null);
  }

  @override
  ResultFuture<List<DepotNote>> fetchNotes(String depotId) async {
    if (!_live) return _real.fetchNotes(depotId);
    final practice = _store.notesFor(depotId);
    if (PracticeIds.isPractice(depotId)) return Success(practice);
    final real = await _real.fetchNotes(depotId);
    return Success([
      ...practice,
      ...real.when(success: (n) => n, failure: (_) => const <DepotNote>[]),
    ]);
  }

  @override
  ResultFuture<void> addNote(String depotId, String body) async {
    if (!_live) return _real.addNote(depotId, body);
    _store.addNote(depotId, body);
    return const Success(null);
  }

  @override
  ResultFuture<List<DepotActivity>> fetchActivities(String depotId) async {
    if (!_live) return _real.fetchActivities(depotId);
    final practice = _store.activitiesFor(depotId);
    if (PracticeIds.isPractice(depotId)) return Success(practice);
    final real = await _real.fetchActivities(depotId);
    return Success([
      ...practice,
      ...real.when(success: (a) => a, failure: (_) => const <DepotActivity>[]),
    ]);
  }

  @override
  ResultFuture<void> addActivity(DepotActivity activity) async {
    if (!_live) return _real.addActivity(activity);
    _store.addActivity(activity);
    return const Success(null);
  }

  static bool _matchesQuery(Depot depot, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return depot.searchableValues
        .any((value) => value.toLowerCase().contains(needle));
  }

  static bool _matchesFilter(Depot depot, DepotFilter filter) {
    if (filter.status != null && depot.status != filter.status) return false;
    if (filter.territory != null && depot.territory != filter.territory) {
      return false;
    }
    return true;
  }
}
