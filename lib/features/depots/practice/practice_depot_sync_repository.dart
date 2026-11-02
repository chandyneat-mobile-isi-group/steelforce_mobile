import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sync_result.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_sync_repository.dart';
import 'package:steelforce/features/depots/practice/practice_depot_store.dart';

/// [DepotSyncRepository] for a practice run.
///
/// The Depots tab pulls `/mobile/depots` when it opens and the detail screen
/// hydrates the depot it shows — both write the encrypted database. During
/// practice the directory *is* the practice store, so a pull reports success
/// with nothing changed and a hydrate has nothing to fetch. Neither reaches the
/// API or Drift.
///
/// Forwards everything to [_real] once [PracticeWorld.isClosed].
class PracticeDepotSyncRepository implements DepotSyncRepository {
  PracticeDepotSyncRepository({
    required DepotSyncRepository real,
    required PracticeWorld world,
    required PracticeDepotStore store,
  })  : _real = real,
        _world = world,
        _store = store;

  final DepotSyncRepository _real;
  final PracticeWorld _world;
  final PracticeDepotStore _store;

  bool get _live => !_world.isClosed;

  /// Message for a path no lesson reaches. A localisation key.
  static const unavailableInPractice = 'common.something_went_wrong';

  @override
  ResultFuture<DateTime?> lastSyncedAt() async {
    if (!_live) return _real.lastSyncedAt();
    return Success(_store.now());
  }

  @override
  ResultFuture<DepotSyncResult> runInitialSync() async {
    if (!_live) return _real.runInitialSync();
    return Success(_nothingChanged());
  }

  @override
  ResultFuture<DepotSyncResult> runDeltaSync() async {
    if (!_live) return _real.runDeltaSync();
    return Success(_nothingChanged());
  }

  @override
  ResultFuture<void> hydrateDepot(String id) async {
    if (!_live) return _real.hydrateDepot(id);
    // A practice depot is already whole; a real one keeps its cached copy —
    // refreshing it would write the database.
    return const Success(null);
  }

  /// The legacy create path (the shell's old Add Depot sheet). No lesson goes
  /// through it, and it writes the database, so during practice it refuses
  /// rather than guess at a practice equivalent.
  @override
  ResultFuture<Depot> createDepot(DepotDraft draft) async {
    if (!_live) return _real.createDepot(draft);
    return const Failed(CacheFailure(message: unavailableInPractice));
  }

  /// No ERP during practice. A practice code resolves to nothing rather than
  /// reaching SAP; the demo depots are all in the list already.
  @override
  ResultFuture<DepotCodeLookup> lookupByCode(String code) async {
    if (!_live) return _real.lookupByCode(code);
    return const Success(DepotCodeAbsent());
  }

  DepotSyncResult _nothingChanged() =>
      DepotSyncResult(upserted: 0, deleted: 0, syncedAt: _store.now());
}
