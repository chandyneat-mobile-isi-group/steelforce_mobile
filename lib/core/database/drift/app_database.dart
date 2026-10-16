import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/connection/database_connection.dart';
import 'package:steelforce/core/database/drift/daos/app_metadata_dao.dart';
import 'package:steelforce/core/database/drift/daos/cart_dao.dart';
import 'package:steelforce/core/database/drift/daos/catalog_dao.dart';
import 'package:steelforce/core/database/drift/daos/depot_dao.dart';
import 'package:steelforce/core/database/drift/daos/depot_registration_queue_dao.dart';
import 'package:steelforce/core/database/drift/daos/geo_dao.dart';
import 'package:steelforce/core/database/drift/daos/route_dao.dart';
import 'package:steelforce/core/database/drift/daos/route_telemetry_dao.dart';
import 'package:steelforce/core/database/drift/daos/notification_dao.dart';
import 'package:steelforce/core/database/drift/daos/order_dao.dart';
import 'package:steelforce/core/database/drift/daos/visit_dao.dart';
import 'package:steelforce/core/database/drift/daos/workflow_state_dao.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:steelforce/core/database/drift/tables/app_metadata_table.dart';
import 'package:steelforce/core/database/drift/tables/cart_items_table.dart';
import 'package:steelforce/core/database/drift/tables/catalog_tables.dart';
import 'package:steelforce/core/database/drift/tables/depot_registration_queue_table.dart';
import 'package:steelforce/core/database/drift/tables/depot_related_tables.dart';
import 'package:steelforce/core/database/drift/tables/depots_table.dart';
import 'package:steelforce/core/database/drift/tables/geo_tables.dart';
import 'package:steelforce/core/database/drift/tables/notification_tables.dart';
import 'package:steelforce/core/database/drift/tables/order_tables.dart';
import 'package:steelforce/core/database/drift/tables/route_tables.dart';
import 'package:steelforce/core/database/drift/tables/visit_tables.dart';
import 'package:steelforce/core/database/drift/tables/workflow_state_table.dart';
import 'package:steelforce/core/database/secure/app_database_key_provider.dart';

part 'app_database.g.dart';

/// The single, SQLCipher-encrypted application database.
///
/// This is the one and only Drift database for the app — all feature tables
/// are added here in later tasks (T1.3 / T2), replacing the per-feature plain
/// `sqflite` stores. Keeping one database means cross-feature transactions and
/// a single, coordinated migration path.
///
/// Construct it via [AppDatabase.encrypted] so it can never be opened without
/// the SQLCipher key.
@DriftDatabase(
  tables: [
    AppMetadata,
    Depots,
    DepotContacts,
    DepotNotes,
    DepotActivities,
    DepotFavorites,
    DepotRecent,
    DepotSyncMeta,
    Categories,
    Products,
    Prices,
    Stock,
    ProductFavorites,
    RecentProducts,
    CatalogSyncMeta,
    CartItems,
    // Route domain (T1.5, v7) — ported from the plaintext `routes.db`.
    Routes,
    RouteStops,
    // The route feed's own flat depot mirror (ADR-011, v18) — what a stop
    // renders from, so stops no longer depend on the depot directory.
    RouteDepots,
    LocationSamples,
    FraudFlags,
    RouteSyncMeta,
    // Ad hoc visit outbox (v25). Holds the `clientRequestId` across retries so
    // an unacknowledged request replays as itself rather than duplicating the
    // visit (docs/feature/my-visits/ad-hoc-visits-mobile.md §7).
    AdHocVisitQueue,
    // Depot registration outbox (v27). Registrations submitted while SAP was
    // out of reach, replayed by the sync engine (ADR-006).
    DepotRegistrationQueue,
    // Visit captures (T1.5, v8) — ported from the plaintext `routes.db`.
    VisitCheckIns,
    VisitCheckOuts,
    VisitOrderLines,
    VisitStockUpdates,
    VisitReturns,
    VisitCollections,
    VisitNotes,
    VisitPhotos,
    // Orders domain (T1.5b, v12) — ported from the plaintext `catalog.db`.
    Quotations,
    SalesOrders,
    SyncQueue,
    // Resume pointer (T1.5b, v13) — the last table in the plaintext `routes.db`.
    WorkflowState,
    // Notification inbox (v19). A pull-only mirror of the server's inbox plus
    // its own outbox, because the inbox — not the push — is the system of
    // record (docs/feature/notification/README.md §1). Encrypted rather than
    // cached in Hive: a notification body names a depot and a route, which
    // is PII (docs/skills/security.md §3).
    Notifications,
    NotificationActionQueue,
    NotificationSyncMeta,
    // Cambodian administrative gazetteer (v20) — bundled reference data, not a
    // sync target. There is no geographic endpoint to sync from; the rows are
    // imported from `assets/geo/kh_geo_seed_v1.json` on first run so a rep with
    // no signal can still complete an address (ADR-002).
    GeoProvinces,
    GeoDistricts,
    GeoCommunes,
    GeoVillages,
  ],
  daos: [
    AppMetadataDao,
    DepotDao,
    DepotRegistrationQueueDao,
    CatalogDao,
    CartDao,
    // Route domain (T1.5) — one DAO per aggregate (ADR-004).
    RouteDao,
    RouteTelemetryDao,
    VisitDao,
    // Orders domain + resume pointer (T1.5b).
    QuotationDao,
    SalesOrderDao,
    SyncQueueDao,
    WorkflowStateDao,
    // Notification inbox + outbox (v19). One DAO for both, because every state
    // change has to write the mirror and enqueue its server call in the same
    // transaction (ADR-006) — two DAOs could not share one.
    NotificationDao,
    // One DAO for all four gazetteer levels (v20). They are read together as a
    // single cascade and re-seeded together in one transaction, so splitting
    // them per level would only prevent that transaction.
    GeoDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the production database for the current platform.
  ///
  /// **On Android/iOS** this is what the name says: SQLCipher, keyed by the
  /// composite passphrase resolved through [keyProvider], refusing to open at
  /// all if encryption is not active (ADR-008).
  ///
  /// **On web** there is no SQLCipher and no persistence — the executor is an
  /// in-memory `sqlite3.wasm` database and [keyProvider] is ignored (ADR-010).
  /// The name is kept because renaming it would churn every call site to
  /// describe a platform difference that this class deliberately does not have;
  /// the platform split lives entirely in `connection/database_connection.dart`,
  /// which is the one file to read for the real guarantees.
  factory AppDatabase.encrypted(AppDatabaseKeyProvider keyProvider) =>
      AppDatabase(openAppDatabaseConnection(keyProvider));

  /// Single source of truth in [kCurrentSchemaVersion]; bumped per schema change.
  @override
  int get schemaVersion => kCurrentSchemaVersion;

  /// Create/upgrade/registry logic lives in the migrations module (T1.4).
  @override
  MigrationStrategy get migration => buildMigrationStrategy(this);
}
