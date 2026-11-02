import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/camera/camera_factory.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/config/env.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/app_database_rekey_executor.dart';
import 'package:steelforce/core/database/secure/app_database_key_provider.dart';
import 'package:steelforce/core/database/secure/app_secure_storage.dart';
import 'package:steelforce/core/database/secure/database_key_rotator.dart';
import 'package:steelforce/core/database/secure/dynamic_key_store.dart';
import 'package:steelforce/core/database/secure/key_derivation.dart';
import 'package:steelforce/core/database/hive/app_preferences.dart';
import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_cubit.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/pdf/document/pdf_assets.dart';
import 'package:steelforce/core/pdf/storage/pdf_file_service.dart';
import 'package:steelforce/core/pdf/pdf_service.dart';
import 'package:steelforce/core/pdf/sharing/pdf_share_service.dart';
import 'package:steelforce/core/session/app_restart_controller.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/practice/practice_session_scoped_store.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/core/session/session_sync_store.dart';
import 'package:steelforce/core/session/device_storage_session_store.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/sync/background/background_sync_runner.dart';
import 'package:steelforce/core/di/offline_data_sources.dart';
import 'package:steelforce/core/sync/offline_data_prefetcher.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_store.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_visit_outbox_sender.dart';
import 'package:steelforce/features/my_visits/data/session/plan_visit_unsent_work_source.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_current_user.dart';
import 'package:steelforce/core/database/drift/local_database_reset.dart';
import 'package:steelforce/features/order/data/local/sync_queue_local_data_source.dart';
import 'package:steelforce/features/order/data/session/quotation_unsent_work_source.dart';
import 'package:steelforce/features/order/presentation/services/quotation_sync_coordinator.dart';
import 'package:steelforce/features/my_visits/data/local/visit_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/session/visit_unsent_work_source.dart';
import 'package:steelforce/features/depots/data/session/depot_registration_unsent_work_source.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';
import 'package:steelforce/features/order/data/session/order_session_scoped_store.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/data/session/visit_session_scoped_store.dart';
import 'package:steelforce/features/app_coach/app_coach_injection.dart';
import 'package:steelforce/features/authentication/authentication_injection.dart';
import 'package:steelforce/features/localization/localization_injection.dart';
import 'package:steelforce/features/depots/depots_injection.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/features/geo_location/geo_location_injection.dart';
import 'package:steelforce/features/my_visits/my_visits_injection.dart';
import 'package:steelforce/features/order/domain/usecases/check_material_availability.dart';
import 'package:steelforce/features/order/order_injection.dart';
import 'package:steelforce/features/notification/notification_injection.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/stock_cubit.dart';
import 'package:steelforce/features/profile/profile_injection.dart';
import 'package:steelforce/features/settings/theme/theme_injection.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/permissions/geolocator_location_permission_service.dart';
import 'package:steelforce/core/permissions/location_permission_service.dart';
import 'package:steelforce/core/permissions/presentation/app_permissions_cubit.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/notification/domain/usecases/push_device_usecases.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/core/network/work_mode/mode_aware_connectivity_service.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';
import 'package:steelforce/features/shell/presentation/bloc/work_mode_cubit.dart';

/// Global service locator.
final GetIt sl = GetIt.instance;

/// Call once from `main()` before `runApp`.
Future<void> initDependencies() async {
  // ── External singletons ────────────────────────────────────────────
  sl.registerLazySingleton<FlutterSecureStorage>(appSecureStorage);
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // ── Encrypted database (Blueprint §3: composite-key SQLCipher) ──────
  sl.registerLazySingleton<DynamicKeyStore>(() => DynamicKeyStore(sl()));
  sl.registerLazySingleton<KeyDerivation>(() => const KeyDerivation());
  sl.registerLazySingleton<AppDatabaseKeyProvider>(
    () => AppDatabaseKeyProvider(
      deviceKeyStore: sl(),
      keyDerivation: sl(),
      salt: Env.dbSalt,
    ),
  );
  sl.registerFactory(() => StockCubit(sl<CheckMaterialAvailability>()));
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase.encrypted(sl()));
  sl.registerLazySingleton<DatabaseRekeyExecutor>(
    () => AppDatabaseRekeyExecutor(sl()),
  );
  sl.registerLazySingleton<DatabaseKeyRotator>(
    () => DatabaseKeyRotator(
      deviceKeyStore: sl(),
      keyDerivation: sl(),
      executor: sl(),
      salt: Env.dbSalt,
    ),
  );

  // ── Observability (docs/skills/security.md §10: structured, PII-free) ──────────
  sl.registerLazySingleton<AppLogger>(() => const ConsoleAppLogger());

  // ── Camera ──────────────────────────────────────────────────────────
  //
  // The one place the runtime environment is allowed to decide anything about
  // the camera. Features resolve `ImageCaptureService` and use what they get;
  // none of them may ask whether it is running on a simulator.
  //
  // Under the default `CAMERA_MODE=auto` this is the real camera everywhere
  // except the iOS Simulator, which has no camera hardware at all. Override
  // with `--dart-define=CAMERA_MODE=mock|real`.
  sl.registerLazySingleton<ImageCaptureService>(
      () => CameraFactory.resolve(navigatorKey: navigatorKey));

  // ── Connectivity (ADR-005: real reachability, not interface-up) ─────
  // One instance, app-wide: the UI status pill and the sync drain trigger must
  // never disagree. No UI/bloc/repository/DAO may touch connectivity_plus.
  sl.registerLazySingleton<ReachabilityProbe>(
    // The demo has no API to probe, so reachability follows the device's
    // network interface alone; otherwise the app would read as permanently
    // offline. Compile-time constant, so mobile builds tree-shake it away.
    () => DataSourceMode.useMocks
        ? const DemoReachabilityProbe()
        : HttpReachabilityProbe(dio: Dio(), logger: sl()),
  );
  // The rep's chosen work mode, persisted in Hive. Registered before
  // connectivity because the app-wide [ConnectivityService] is the device's
  // reachability *combined with* this choice: offline mode reads as offline
  // to every consumer, so sync, pulls and banners follow it with no per-feature
  // wiring (see [ModeAwareConnectivityService]).
  sl.registerLazySingleton<WorkModeService>(
    () => HiveWorkModeService(HiveService.cacheBox),
  );
  sl.registerLazySingleton<ConnectivityService>(
    () => ModeAwareConnectivityService(
      device: ConnectivityServiceImpl(
        connectivity: sl(),
        probe: sl(),
        logger: sl(),
      ),
      workMode: sl(),
    ),
  );

  sl.registerFactory<ConnectivityCubit>(() => ConnectivityCubit(sl()));
  // Real reachability and Offline Mode, not just "a radio is on" — so a
  // phone with Wi-Fi but no internet reads its own data at once instead of
  // waiting out request timeouts (ADR-005).
  sl.registerLazySingleton<NetworkInfo>(() => ReachableNetworkInfo(
        connectivity: sl(),
        reachability: sl<ConnectivityService>(),
        workMode: sl<WorkModeService>(),
      ));
  sl.registerLazySingleton<SessionManager>(() => SessionManager());
  sl.registerLazySingleton<AppRestartController>(() => AppRestartController());
  sl.registerLazySingleton<AppPreferences>(
    () => AppPreferencesImpl(HiveService.cacheBox),
  );
  // ── PDF export (reusable across every CRM document type) ────────────
  // Feature-agnostic: generators (quotation/invoice/report…) plug into the
  // same PdfService/File/Share pipeline. PdfAssets caches fonts+logo once.
  sl.registerLazySingleton<PdfAssets>(() => PdfAssets());
  sl.registerLazySingleton<PdfService>(() => PdfServiceImpl(sl<PdfAssets>()));
  sl.registerLazySingleton<PdfFileService>(() => const PdfFileServiceImpl());
  sl.registerLazySingleton<PdfShareService>(() => const PdfShareServiceImpl());

  registerLocalizationFeature(sl);
  sl.registerLazySingleton<ShellTabController>(() => ShellTabController());
  // App-wide, like the mode it reflects: the shell control and the sync sheet
  // read the same instance, so they can never show different modes.
  sl.registerLazySingleton<WorkModeCubit>(
    () => WorkModeCubit(
      workMode: sl<WorkModeService>(),
      waitForSyncIdle: () => sl<SyncEngine>().whenIdle(),
      countUnsent: () => sl<UnsentWorkService>().count(),
      refreshConnectivity: () => sl<ConnectivityService>().refresh(),
    ),
  );
  registerThemeFeature(sl);

  // Before the features: each contributes its practice stand-ins at
  // registration time (see PracticeSession).
  sl.registerLazySingleton<PracticeSession>(() => PracticeSession(sl));

  // ── Features ───────────────────────────────────────────────────────
  registerAuthFeature(sl);

  await registerOrderFeature(sl);
  await registerDepotFeature(sl);
  // Shared address component. After the depot feature only for readability —
  // its one real dependency is `AppDatabase`, registered above.
  registerGeoLocationFeature(sl);
  // After auth, which supplies the authenticated `Dio` and the `DeviceIdentity`
  // whose per-installation id is the upsert key for a push registration
  // (docs/feature/notification/api/devices-register.md). The feed is no longer derived
  // from the depot cache — it is the real inbox now.
  registerNotificationFeature(sl);
  await registerMyVisitsFeature(sl);
  registerProfileFeature(sl);
  registerAppCoachFeature(sl);

  // ── OS permissions ─────────────────────────────────────────────────
  //
  // Registered after the notification feature because the primer's device
  // registration resolves `RegisterPushDevice` from it. Both are lazy, so this
  // is about readability rather than necessity — but the dependency is real and
  // worth stating where somebody reordering these lines will see it.
  //
  // Location lives in `core/` alongside the push transport rather than in a
  // feature: `features/order` and `features/my_visits` both read a position, and
  // one dialog primes both permissions, so no single feature can own it without
  // another importing its internals (playbook §12).
  sl.registerLazySingleton<LocationPermissionService>(
    () => GeolocatorLocationPermissionService(sl<AppLogger>()),
  );

  // A factory: the primer is per-presentation and is closed with the dialog
  // that built it. A singleton would keep a settled state around and report
  // "already answered" to the next caller.
  sl.registerFactory<AppPermissionsCubit>(
    () => AppPermissionsCubit(
      messaging: sl(),
      location: sl(),
      cache: LocalCache(HiveService.cacheBox),
      logger: sl<AppLogger>(),
      // A callback, not a repository. Registering the handset belongs to the
      // notification feature, and `core/` must not depend on a feature — the
      // same seam the inbox cubit uses for an action's `api_call`.
      registerPushDevice: () async {
        await sl<RegisterPushDevice>()(const NoParams());
      },
    ),
  );

  // ── Sign-out fan-out ───────────────────────────────────────────────
  //
  // Registered after every feature so each one's repositories exist to be
  // resolved. Adding a feature that holds rep-scoped data means adding one
  // entry here — the logout path itself never changes.
  //
  // Sign-out leaves nothing of the session behind: the whole encrypted
  // database (bar the bundled gazetteer), Hive, sandbox files and downloaded
  // images. Every screen reads from the API again after the next sign-in.
  sl.registerLazySingleton<SessionResetService>(
    () => SessionResetService(
      [
        // Stop active pulls/drains first. They must be idle before any store
        // or the database is cleared, or an old response could repopulate it.
        SessionSyncStore(
          engine: sl<SyncEngine>(),
          prefetcher: sl<OfflineDataPrefetcher>(),
        ),
        // Practice must be over before the feature stores clear, so they
        // reach the real stores and not its in-memory stand-ins.
        PracticeSessionScopedStore(sl<PracticeSession>()),
        OrderSessionScopedStore(sl<CartRepository>()),
        VisitSessionScopedStore(sl<ActiveWorkflowRepository>()),
        DeviceStorageSessionStore(
          secureBox: HiveService.secureBox,
          cacheBox: HiveService.cacheBox,
        ),
        // Last: the stores above read through it.
        LocalDatabaseSessionStore(sl<AppDatabase>()),
      ],
      sl<AppLogger>(),
    ),
  );
  sl.registerLazySingleton<LocalDataOwnership>(
    () => LocalDataOwnership(sl<AppDatabase>(), sl<SessionResetService>()),
  );

  // Because that wipe would destroy it, sign-out is refused while any of
  // this is still waiting to reach the server.
  sl.registerLazySingleton<UnsentWorkService>(
    () => UnsentWorkService(
      // The order here is the order the server receives things in — the
      // sync engine sends these top to bottom, and quotations and visit
      // pushes started elsewhere first send whatever is above them
      // (`UnsentWorkService.sendBefore`). For every stop worked offline that
      // is check-in, then the orders taken there, then check-out.
      [
        // First: a depot registered offline is what a later visit or quotation
        // for that shop may hang off.
        DepotRegistrationUnsentWorkSource(sl<DepotRegistrationOutbox>()),
        VisitCheckInUnsentWorkSource(
          visits: sl<VisitLocalDataSource>(),
          visitSync: sl<VisitSyncRepository>(),
          adHoc: sl<AdHocVisitRepository>(),
        ),
        // Plan visits worked offline: check-in, then photos, then check-out.
        PlanVisitUnsentWorkSource(
          store: sl<PlanVisitOutboxStore>(),
          sender: sl<PlanVisitOutboxSender>(),
        ),
        QuotationUnsentWorkSource(
          sl<SyncQueueLocalDataSource>(),
          // No review read-back: the coordinator does that itself on
          // reconnect and resume, and this runs on every drain.
          send: () => sl<QuotationSyncCoordinator>().runNow(reviews: false),
        ),
        VisitUnsentWorkSource(
          visits: sl<VisitLocalDataSource>(),
          visitSync: sl<VisitSyncRepository>(),
        ),
      ],
      sl<AppLogger>(),
    ),
  );

  // The same sources, sent automatically: on sign-in, reconnect, resume and a
  // backing-off retry timer. Started and stopped with the signed-in shell.
  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      unsentWork: sl<UnsentWorkService>(),
      connectivity: sl<ConnectivityService>(),
      logger: sl<AppLogger>(),
      isAuthenticated: () => sl<SessionManager>().isAuthenticated,
    ),
  );

  // The pull side: everything the rep needs on the device to keep working
  // offline, fetched when the signed-in shell starts and on every return to
  // reachability — not only when each screen happens to be opened.
  sl.registerLazySingleton<OfflineDataPrefetcher>(
    () => OfflineDataPrefetcher(
      sources: () => offlineDataSources(sl),
      connectivity: sl<ConnectivityService>(),
      logger: sl<AppLogger>(),
      isAuthenticated: () => sl<SessionManager>().isAuthenticated,
    ),
  );

  // One background-worker run (OS-scheduled, best effort). The session restore
  // mirrors `AuthBloc`'s boot check — the cached profile and token, no network
  // — because a headless isolate has no AuthBloc to do it.
  sl.registerLazySingleton<BackgroundSyncRunner>(
    () => BackgroundSyncRunner(
      unsentWork: sl<UnsentWorkService>(),
      connectivity: sl<ConnectivityService>(),
      logger: sl<AppLogger>(),
      restoreSession: () async {
        final session = sl<SessionManager>();
        if (session.isAuthenticated) return true;
        final result = await sl<GetCurrentUser>()(const NoParams());
        return result.when(
          success: (profile) {
            session.setUser(profile.toUser(),
                permissions: profile.permissions,
                territoryCode: profile.territoryCode);
            return true;
          },
          failure: (_) => false,
        );
      },
    ),
  );
}
