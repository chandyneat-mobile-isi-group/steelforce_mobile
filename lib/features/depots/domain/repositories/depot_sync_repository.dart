import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sync_result.dart';

/// The only door into the remote SAP depot feed. Deliberately separate
/// from [DepotRepository] — reads always go local, sync is the one path
/// allowed to write a `Depot` row, which is how the "SAP-created only"
/// entry rule is enforced structurally rather than by convention.
abstract interface class DepotSyncRepository {
  ResultFuture<DateTime?> lastSyncedAt();
  ResultFuture<DepotSyncResult> runInitialSync();
  ResultFuture<DepotSyncResult> runDeltaSync();

  /// Fetches the full aggregate for one depot and writes it to the local
  /// cache, so the detail screen keeps reading locally like every other view.
  ///
  /// The list DTO the sync loop stores is about a fifth of a depot — no
  /// street address, no contacts, no SAP block, no metric cache. This fills
  /// those in on demand rather than paying for them on every row of every
  /// page.
  ///
  /// Best-effort by design: the detail screen must still render from cache
  /// when this fails, because a rep standing in a shop with no signal needs
  /// the depot record more than anyone.
  ResultFuture<void> hydrateDepot(String id);

  /// Registers a new depot and stores the server's version of it.
  ///
  /// The one path by which a `Depot` row is created rather than synced. It
  /// still goes through this repository because the row must land in the local
  /// cache the same way every other one does — the rep expects the shop they
  /// just registered to appear in their list immediately.
  ///
  /// **The server's response is what gets stored, not the draft.** It carries
  /// the assigned id, the `Draft` status and the SAP block the client is not
  /// allowed to set; persisting the draft instead would put a depot in the
  /// cache that the server would contradict on the next sync.
  ResultFuture<Depot> createDepot(DepotDraft draft);

  /// Resolves a depot number the local book does not have.
  ///
  /// The server checks its database first and asks SAP only on a miss, which is
  /// what makes this useful: a depot created in the ERP since the last
  /// nightly sync is invisible to search but findable here.
  ///
  /// **Only for an explicit full-code lookup** — a rep typing or scanning a
  /// depot number. Never the keystroke path: it can reach the ERP, and the
  /// browse list is local precisely so search costs nothing.
  ///
  /// The outcome is a [DepotCodeLookup], not a nullable depot, so a
  /// caller cannot conflate "does not exist" with "could not ask" — see that
  /// type for why the difference is expensive.
  ResultFuture<DepotCodeLookup> lookupByCode(String code);
}
