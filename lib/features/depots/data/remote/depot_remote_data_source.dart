import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/remote/depot_sync_page.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';

/// The SAP depot master, as seen from the mobile app. Only ever called
/// by the sync repository — this is intentionally the single choke point
/// through which a `Depot` row can come into existence locally.
abstract interface class DepotRemoteDataSource {
  Future<DepotInitialPage> fetchInitial({
    required int page,
    required int pageSize,
  });

  /// Records changed at or after [since], **including tombstones**.
  ///
  /// [page] exists because a delta pages like any other list: a rep returning
  /// from a week offline can easily exceed one page of changes.
  Future<DepotDeltaPage> fetchDelta({
    required DateTime since,
    int page,
    int pageSize,
  });

  /// The full aggregate for one depot, which the list DTO deliberately does
  /// not carry — contacts, the SAP block, the street address and the metric
  /// cache all arrive here.
  Future<DepotModel> fetchById(String id);

  /// Registers a new depot — `POST /mobile/depots`, 201.
  ///
  /// The one exception to "a Depot row only ever comes from SAP": a rep
  /// registering a shop in the field creates it here, and it lands in `Draft`
  /// where it cannot trade until someone holding `depots.approve` activates
  /// it. Requires `depots.create`; a rep without it gets 403.
  Future<DepotModel> create(DepotDraft draft);

  /// `GET /depots/by-code/{code}` — resolves a depot number the local
  /// book does not have.
  ///
  /// The server checks its own database first and consults SAP only on a miss,
  /// storing whatever it finds, so the next lookup is local. **Only for an
  /// explicit full-code lookup** — never the keystroke path, because it can
  /// reach the ERP.
  ///
  /// Returns a [DepotCodeLookup] rather than a nullable depot so that
  /// "not found" (safe to offer registration) and "could not reach the ERP"
  /// (offering registration would duplicate a business partner in SAP) cannot
  /// be collapsed into one branch.
  Future<DepotCodeLookup> lookupByCode(String code);
}
