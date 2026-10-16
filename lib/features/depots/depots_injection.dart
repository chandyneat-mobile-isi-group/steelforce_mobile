import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:steelforce/features/depots/data/local/rep_sales_context_source.dart';
import 'package:steelforce/features/depots/data/local/session_rep_sales_context_source.dart';
import 'package:steelforce/features/depots/data/local/depot_drift_local_data_source.dart';
import 'package:steelforce/features/depots/data/local/depot_local_data_source.dart';
import 'package:steelforce/features/depots/data/local/bp_draft_cache.dart';
import 'package:steelforce/features/depots/data/local/depot_reference_cache.dart';
import 'package:steelforce/features/depots/data/local/master_data_cache.dart';
import 'package:steelforce/features/depots/data/mock/demo_business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_document_remote_data_source.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_stop_information_remote_data_source.dart';
import 'package:steelforce/features/depots/data/mock/demo_master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/data/mock/demo_registration_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/api_depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_document_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_document_repository_impl.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/data/repositories/depot_repository_impl.dart';
import 'package:steelforce/features/depots/data/datasources/business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/business_partner_repository_impl.dart';
import 'package:steelforce/features/depots/data/repositories/depot_registration_outbox_impl.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart'
    as bp;
import 'package:steelforce/features/depots/data/repositories/depot_sync_repository_impl.dart';
import 'package:steelforce/features/depots/data/repositories/master_data_repository_impl.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_sync_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/master_data_repository.dart';
import 'package:steelforce/features/depots/domain/usecases/add_depot_activity.dart';
import 'package:steelforce/features/depots/domain/usecases/add_depot_note.dart';
import 'package:steelforce/features/depots/domain/usecases/create_business_partner.dart';
import 'package:steelforce/features/depots/domain/usecases/create_depot.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_depot_activities.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_depot_notes.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_favorite_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_recent_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_by_id.dart';
import 'package:steelforce/features/depots/domain/usecases/hydrate_depot.dart';
import 'package:steelforce/features/depots/domain/usecases/lookup_depot_by_code.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_master_data.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_last_synced_at.dart';
import 'package:steelforce/features/depots/domain/usecases/refresh_master_data.dart';
import 'package:steelforce/features/depots/domain/usecases/record_depot_viewed.dart';
import 'package:steelforce/features/depots/domain/usecases/run_depot_delta_sync.dart';
import 'package:steelforce/features/depots/domain/usecases/run_depot_initial_sync.dart';
import 'package:steelforce/features/depots/domain/usecases/toggle_favorite_depot.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_code_lookup_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_detail_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depots_bloc.dart';
import 'package:steelforce/features/depots/presentation/bloc/add_depot_bloc.dart';
import 'package:steelforce/features/depots/presentation/bloc/business_partner_submission.dart';
import 'package:steelforce/features/depots/data/remote/depot_stop_information_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_stop_information_repository_impl.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_stop_information_repository.dart';

/// Registers the approved-depot directory. Persistence is the single
/// SQLCipher-encrypted Drift database (`AppDatabase`) via [DepotDao] — the
/// legacy plaintext `depots.db` was retired in the T2 cutover.
Future<void> registerDepotFeature(GetIt sl) async {
  // ── Data sources ────────────────────────────────────────────────────
  sl.registerLazySingleton<DepotLocalDataSource>(
    () => DepotDriftLocalDataSource(sl<AppDatabase>().depotDao),
  );

  // TODO(release-gate): a demo build (`USE_MOCK_DATA=true`) answers every
  // depot route from this in-memory book instead of the API. Shared by the
  // demo sources below so a shop registered through one is visible to the
  // others. Never registered in a live build.
  if (DataSourceMode.useMocks) {
    sl.registerLazySingleton<DemoDepotDirectory>(DemoDepotDirectory.new);
  }

  // The depot *directory* feed — `GET /mobile/depots`, consumed by
  // DepotSyncRepositoryImpl.
  //
  // Note there are two unrelated interfaces named `DepotRemoteDataSource`:
  // this one (`data/remote/depot_remote_data_source.dart`) and the BP
  // registration one below, imported as `bp`. They are different types, so
  // registering one does NOT satisfy the other — omitting this line fails at
  // runtime, not compile time, with "DepotRemoteDataSource is not
  // registered" when the Depots screen builds.
  // TODO(release-gate): demo builds use the in-memory demo book.
  sl.registerLazySingleton<DepotRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiDepotRemoteDataSource(sl<Dio>())
        : DemoDepotRemoteDataSource(
            sl<DemoNetwork>(), sl<DemoDepotDirectory>()),
  );

  // SAP Depot Helper master data (ADR-009). Cached in Hive rather than
  // Drift because these are regenerable lookups, not business records
  // (ARCHITECTURE.md §3, Layer 2) — so this needs no schema migration.
  // TODO(release-gate): demo builds add the demo network's offline switch
  // on top of the same mock rows a live build still uses (see the mock's own
  // release-gate note — there is no SAP-backed implementation yet).
  sl.registerLazySingleton<MasterDataRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? const MockMasterDataRemoteDataSource()
        : DemoMasterDataRemoteDataSource(sl<DemoNetwork>()),
  );
  sl.registerLazySingleton<MasterDataCache>(
    () => MasterDataCache(LocalCache(HiveService.cacheBox)),
  );

  // ── Repositories ────────────────────────────────────────────────────
  sl.registerLazySingleton<DepotRepository>(() => DepotRepositoryImpl(sl()));
  // TODO(release-gate): demo builds use the in-memory demo book.
  sl.registerLazySingleton<bp.DepotRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? bp.DepotRemoteDataSourceImpl(sl<Dio>())
        : DemoRegistrationRemoteDataSource(
            sl<DemoNetwork>(), sl<DemoDepotDirectory>()),
  );
  // Hive, not Drift: regenerable ERP lookups are Layer 2 (ADR-009), so this
  // needs no schema migration.
  sl.registerLazySingleton<DepotReferenceCache>(
    () => DepotReferenceCache(LocalCache(HiveService.cacheBox)),
  );
  // Evidence photographs. Separate from the registration repository because the
  // lifetime differs — they outlive the draft and are edited from the detail
  // screen long after registration closed.
  // The outlet profile behind a visit's stop screen. Owned here rather than in
  // `my_visits` because the endpoint is `/mobile/depots/{id}/stop-information`
  // — my_visits consumes it through the domain interface (CLAUDE.md §4).
  // TODO(release-gate): demo builds use the in-memory demo book.
  sl.registerLazySingleton<DepotStopInformationRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiDepotStopInformationRemoteDataSource(sl<Dio>())
        : DemoDepotStopInformationRemoteDataSource(
            sl<DemoNetwork>(), sl<DemoDepotDirectory>()),
  );
  sl.registerLazySingleton<DepotStopInformationRepository>(
    () => DepotStopInformationRepositoryImpl(
      remote: sl<DepotStopInformationRemoteDataSource>(),
      network: sl<NetworkInfo>(),
      logger: sl<AppLogger>(),
    ),
  );

  // TODO(release-gate): demo builds keep documents in memory.
  sl.registerLazySingleton<DepotDocumentRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiDepotDocumentRemoteDataSource(sl<Dio>())
        : DemoDepotDocumentRemoteDataSource(sl<DemoNetwork>()),
  );
  sl.registerLazySingleton<DepotDocumentRepository>(
    () => DepotDocumentRepositoryImpl(
      remote: sl<DepotDocumentRemoteDataSource>(),
      logger: sl<AppLogger>(),
    ),
  );
  // The single-write registration endpoint,
  // `POST /api/v1/mobile/depots/business-partner`. Separate from
  // `bp.DepotRemoteDataSource`, which still owns `GET /references` and the
  // retired draft routes — the two are different types and both are needed.
  // TODO(release-gate): demo builds register into the in-memory demo book.
  sl.registerLazySingleton<BusinessPartnerRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? BusinessPartnerRemoteDataSourceImpl(sl<Dio>())
        : DemoBusinessPartnerRemoteDataSource(
            sl<DemoNetwork>(), sl<DemoDepotDirectory>()),
  );

  // Hive, not Drift: an in-progress form is UI state that survives a process
  // kill, not a business record, so it needs no schema migration (ADR-009).
  //
  // The *encrypted* box: the form holds depot names, phones, addresses and ID
  // photographs' paths — PII, which may not sit in the plain cache box
  // (security.md §2). The plain box is passed only so a draft written there by
  // an older build is moved across and erased.
  sl.registerLazySingleton<BpDraftCache>(
    () => BpDraftCache(
      LocalCache(HiveService.secureBox),
      legacyPlaintext: LocalCache(HiveService.cacheBox),
    ),
  );
  // Run once at start-up rather than on first open, so plaintext PII does not
  // linger on the device until the rep next happens to register a shop.
  // Local disk only; never throws.
  await sl<BpDraftCache>().migrateLegacyPlaintext();

  // The signed-in rep's personnel number, from the session and cached
  // profile. Replaces a hard-coded employee id that stamped every rep's
  // registrations against one person.
  sl.registerLazySingleton<RepSalesContextSource>(
    () => SessionRepSalesContextSource(
      auth: sl<AuthRepository>(),
      session: sl<SessionManager>(),
    ),
  );

  sl.registerLazySingleton<BusinessPartnerRepository>(
    () => BusinessPartnerRepositoryImpl(
      remote: sl<BusinessPartnerRemoteDataSource>(),
      references: sl<bp.DepotRemoteDataSource>(),
      referenceCache: sl<DepotReferenceCache>(),
      draftCache: sl<BpDraftCache>(),
      network: sl<NetworkInfo>(),
    ),
  );
  // Registrations submitted while SAP was out of reach. Replayed by the sync
  // engine, which `onEnqueued` wakes; resolved lazily because the engine is
  // registered after every feature.
  sl.registerLazySingleton<DepotRegistrationOutbox>(
    () => DepotRegistrationOutboxImpl(
      dao: sl<AppDatabase>().depotRegistrationQueueDao,
      registrations: sl<BusinessPartnerRepository>(),
      documents: sl<DepotDocumentRepository>(),
      draftCache: sl<BpDraftCache>(),
      logger: sl<AppLogger>(),
      onEnqueued: () {
        if (sl.isRegistered<SyncEngine>()) sl<SyncEngine>().requestSync();
      },
    ),
  );
  sl.registerLazySingleton<DepotSyncRepository>(
    () => DepotSyncRepositoryImpl(
      remote: sl(),
      local: sl(),
      network: sl<NetworkInfo>(),
      logger: sl<AppLogger>(),
    ),
  );
  sl.registerLazySingleton<MasterDataRepository>(
    () => MasterDataRepositoryImpl(
      remote: sl(),
      cache: sl(),
      network: sl<NetworkInfo>(),
    ),
  );

  // ── Use cases ───────────────────────────────────────────────────────
  sl.registerLazySingleton(() => BrowseDepots(sl()));
  sl.registerLazySingleton(() => CreateDepot(sl()));
  sl.registerLazySingleton(() => CreateBusinessPartner(sl()));
  sl.registerLazySingleton(() => ValidateBusinessPartner(sl()));
  sl.registerLazySingleton(() => GetDepotById(sl()));
  sl.registerLazySingleton(() => HydrateDepot(sl()));
  sl.registerLazySingleton(() => ToggleFavoriteDepot(sl()));
  sl.registerLazySingleton(() => FetchFavoriteDepots(sl()));
  sl.registerLazySingleton(() => FetchRecentDepots(sl()));
  sl.registerLazySingleton(() => RecordDepotViewed(sl()));
  sl.registerLazySingleton(() => FetchDepotNotes(sl()));
  sl.registerLazySingleton(() => AddDepotNote(sl()));
  sl.registerLazySingleton(() => FetchDepotActivities(sl()));
  sl.registerLazySingleton(() => AddDepotActivity(sl()));
  sl.registerLazySingleton(() => RunDepotInitialSync(sl()));
  sl.registerLazySingleton(() => RunDepotDeltaSync(sl()));
  sl.registerLazySingleton(() => GetDepotLastSyncedAt(sl()));
  sl.registerLazySingleton(() => LookupDepotByCode(sl()));
  sl.registerLazySingleton(() => FetchMasterData(sl()));
  sl.registerLazySingleton(() => RefreshMasterData(sl()));

  // ── Presentation ────────────────────────────────────────────────────
  sl.registerFactory(
    () => DepotsBloc(
      browseDepots: sl(),
      fetchRecentDepots: sl(),
      toggleFavoriteDepot: sl(),
    ),
  );
  // Holds the draft -> payload mapping. A singleton rather than part of the
  // bloc so the mapping can be unit-tested, and so a future offline replay
  // worker builds the payload the same way the wizard does.
  sl.registerLazySingleton(
    () => BusinessPartnerSubmission(
      createBusinessPartner: sl(),
      validateBusinessPartner: sl(),
    ),
  );

  sl.registerFactory(
    () => AddDepotBloc(
      repository: sl(),
      documents: sl<DepotDocumentRepository>(),
      submission: sl<BusinessPartnerSubmission>(),
      repSource: sl<RepSalesContextSource>(),
      outbox: sl<DepotRegistrationOutbox>(),
    ),
  );
  sl.registerFactory(
    () => DepotDetailCubit(
      getDepotById: sl(),
      hydrateDepot: sl(),
      fetchDepotNotes: sl(),
      addDepotNote: sl(),
      fetchDepotActivities: sl(),
      addDepotActivity: sl(),
      recordDepotViewed: sl(),
    ),
  );
  sl.registerFactory(() => DepotCodeLookupCubit(sl()));
  sl.registerFactory(
    () => DepotRegistrationQueueCubit(
      outbox: sl<DepotRegistrationOutbox>(),
      syncNow: () => sl<SyncEngine>().runNow(),
    ),
  );
  sl.registerFactory(
    () => DepotSyncCubit(
      runInitialSync: sl(),
      runDeltaSync: sl(),
      getLastSyncedAt: sl(),
      session: sl<SessionManager>(),
      logger: sl<AppLogger>(),
    ),
  );
}
