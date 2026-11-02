import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_channel.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_channel_source.dart';
import 'package:steelforce/features/depots/data/local/drift_depot_channel_source.dart';
import 'package:steelforce/features/depots/domain/usecases/load_depot_filter_options.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_filter_options_source.dart';
import 'package:steelforce/features/depots/data/local/drift_depot_filter_options_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_supplier_namer.dart';
import 'package:steelforce/features/depots/data/local/division_names.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/practice/practice_session.dart';
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
import 'package:steelforce/features/depots/data/remote/api_depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/data/datasources/mock_business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_backend.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_document_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_stop_information_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_document_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_document_repository_impl.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';
import 'package:steelforce/features/depots/data/repositories/depot_repository_impl.dart';
import 'package:steelforce/features/depots/data/datasources/business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/business_partner_repository_impl.dart';
import 'package:steelforce/features/depots/data/repositories/depot_draft_outbox_route.dart';
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
import 'package:steelforce/features/depots/presentation/bloc/supplying_depot_picker_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/business_partner_submission.dart';
import 'package:steelforce/features/depots/data/remote/depot_stop_information_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_stop_information_repository_impl.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_stop_information_repository.dart';
import 'package:steelforce/features/depots/practice/depot_practice_module.dart';
import 'package:steelforce/features/depots/depot_draft_injection.dart';
import 'package:steelforce/features/depots/data/remote/depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/usecases/registration/create_depot_draft.dart';
import 'package:steelforce/features/depots/domain/usecases/registration/load_depot_draft_attachments.dart';
import 'package:steelforce/features/depots/domain/usecases/registration/load_depot_references.dart';
import 'package:steelforce/features/depots/domain/usecases/registration/load_supplier_options.dart';
import 'package:steelforce/features/depots/domain/usecases/registration/upload_depot_evidence.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_draft_submission.dart';

/// Registers the approved-depot directory. Persistence is the single
/// SQLCipher-encrypted Drift database (`AppDatabase`) via [DepotDao] — the
/// legacy plaintext `depots.db` was retired in the T2 cutover.
Future<void> registerDepotFeature(GetIt sl) async {
  // ── Data sources ────────────────────────────────────────────────────
  // Each remote source below is the live API unless the build was made with
  // USE_MOCK_DATA=true, in which case all of them answer from one in-memory
  // demo backend and nothing in this feature reaches the network.
  // TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
  if (DataSourceMode.useMocks) {
    sl.registerLazySingleton<MockDepotBackend>(MockDepotBackend.new);
  }
  sl.registerLazySingleton<DepotLocalDataSource>(
    () => DepotDriftLocalDataSource(sl<AppDatabase>().depotDao),
  );

  // The depot *directory* feed — `GET /mobile/depots`, consumed by
  // DepotSyncRepositoryImpl.
  //
  // Note there are two unrelated interfaces named `DepotRemoteDataSource`:
  // this one (`data/remote/depot_remote_data_source.dart`) and the BP
  // registration one below, imported as `bp`. They are different types, so
  // registering one does NOT satisfy the other — omitting this line fails at
  // runtime, not compile time, with "DepotRemoteDataSource is not
  // registered" when the Depots screen builds.
  sl.registerLazySingleton<DepotRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiDepotRemoteDataSource(
            sl<Dio>(),
            // The detail answer names suppliers by code; the rep reads names.
            suppliers: DepotSupplierNamer((type) =>
                sl<DepotDraftRemoteDataSource>().fetchSupplierOptions(type)),
          )
        : MockDepotRemoteDataSource(sl<MockDepotBackend>()),
  );

  // SAP Depot Helper master data (ADR-009). Cached in Hive rather than
  // Drift because these are regenerable lookups, not business records
  // (ARCHITECTURE.md §3, Layer 2) — so this needs no schema migration.
  sl.registerLazySingleton<MasterDataRemoteDataSource>(
    () => const MockMasterDataRemoteDataSource(),
  );
  sl.registerLazySingleton<MasterDataCache>(
    () => MasterDataCache(LocalCache(HiveService.cacheBox)),
  );

  // ── Repositories ────────────────────────────────────────────────────
  // The Advanced Filters choices: what the stored depots carry.
  sl.registerLazySingleton<DepotFilterOptionsSource>(
      () => DriftDepotFilterOptionsSource(sl<AppDatabase>().depotDao));
  sl.registerLazySingleton(() => LoadDepotFilterOptions(sl()));
  // A depot's channel for screens outside this feature (visit plan cards).
  sl.registerLazySingleton<DepotChannelSource>(
      () => DriftDepotChannelSource(sl<AppDatabase>().depotDao));
  sl.registerLazySingleton(() => GetDepotChannel(sl()));
  sl.registerLazySingleton<DepotRepository>(() => DepotRepositoryImpl(sl(),
      logger: sl<AppLogger>(),
      divisionNames: DivisionNames(() =>
          sl<DepotReferenceCache>().readStale(includeInactive: true) ??
          sl<DepotReferenceCache>().readStale())));
  sl.registerLazySingleton<bp.DepotRemoteDataSource>(
    () => bp.DepotRemoteDataSourceImpl(sl<Dio>()),
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
  sl.registerLazySingleton<DepotStopInformationRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiDepotStopInformationRemoteDataSource(sl<Dio>())
        : MockDepotStopInformationRemoteDataSource(sl<MockDepotBackend>()),
  );
  sl.registerLazySingleton<DepotStopInformationRepository>(
    () => DepotStopInformationRepositoryImpl(
      remote: sl<DepotStopInformationRemoteDataSource>(),
      network: sl<NetworkInfo>(),
      logger: sl<AppLogger>(),
    ),
  );

  sl.registerLazySingleton<DepotDocumentRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiDepotDocumentRemoteDataSource(sl<Dio>())
        : MockDepotDocumentRemoteDataSource(sl<MockDepotBackend>()),
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
  sl.registerLazySingleton<BusinessPartnerRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? BusinessPartnerRemoteDataSourceImpl(sl<Dio>())
        : MockBusinessPartnerRemoteDataSource(sl<MockDepotBackend>()),
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
      references: sl<DepotDraftRemoteDataSource>(),
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
      drafts: DepotDraftOutboxRoute(sl<DepotDraftRepository>()),
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
  registerDepotUseCases(sl);
  registerDepotDraftFeature(sl);

  // ── Practice ────────────────────────────────────────────────────────
  // While an App Coach lesson runs, the real depot screens work over
  // in-memory stand-ins: nothing reaches Drift, Hive, the registration outbox
  // or the API. The use cases are rebuilt over the stand-ins by the same
  // function as above, so a use case added later cannot drift out of the
  // sandbox.
  sl<PracticeSession>().contribute(registerDepotPracticeScope);

  // ── Presentation ────────────────────────────────────────────────────
  sl.registerFactory(
    () => DepotsBloc(
      browseDepots: sl(),
      fetchRecentDepots: sl(),
      toggleFavoriteDepot: sl(),
    ),
  );
  sl.registerFactory(
    () => AddDepotBloc(
      repository: sl(),
      documents: sl<DepotDocumentRepository>(),
      draftSubmission: sl<DepotDraftSubmission>(),
      outbox: sl<DepotRegistrationOutbox>(),
      repSource: sl<RepSalesContextSource>(),
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
  sl.registerFactory(() => SupplyingDepotPickerCubit(sl()));
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

/// Registers every depot use case — and [BusinessPartnerSubmission], which
/// captures two of them — against whatever repositories [sl] currently
/// resolves.
///
/// Called once for the app, and again inside the practice scope after the
/// practice stand-ins are registered, so every use case a lesson screen
/// reaches is built over the stand-ins rather than over a base-scope singleton
/// that already holds the real repository.
void registerDepotUseCases(GetIt sl) {
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

  // New-depot registration (`/api/v1/depot-drafts`).
  sl.registerLazySingleton(() => CreateDepotDraft(sl()));
  sl.registerLazySingleton(() => LoadDepotReferences(sl()));
  sl.registerLazySingleton(() => LoadSupplierOptions(sl()));
  sl.registerLazySingleton(() => UploadDepotEvidence(sl()));
  sl.registerLazySingleton(() => LoadDepotDraftAttachments(sl()));
  sl.registerLazySingleton(
    () => DepotDraftSubmission(createDraft: sl(), uploadEvidence: sl()),
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
}

/// The depot feature's contribution to a practice scope: the stand-ins, then
/// every use case rebuilt over them.
void registerDepotPracticeScope(GetIt sl, PracticeWorld world) {
  registerDepotPracticeStandIns(sl, world);
  registerDepotUseCases(sl);
}
