import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/session/location_heartbeat_service.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/data/local/depot_selection_store.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/route_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/workflow_state_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_location_tracking_service.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/active_workflow_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/ad_hoc_visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/location_sample_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/services/geolocator_tracking_service.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/location_sample_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_sync_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/services/stop_distance_sorter.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';
import 'package:steelforce/features/my_visits/domain/services/proof_photo_service.dart';
import 'package:steelforce/features/my_visits/presentation/services/camera_proof_photo_service.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_ad_hoc_visit.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_collection.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_order_line.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_return.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_stock_update.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_note.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_in.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/clear_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/complete_visit_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_resumable_route.dart';
import 'package:steelforce/features/my_visits/domain/usecases/push_pending_visit_data.dart';
import 'package:steelforce/features/my_visits/domain/usecases/save_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_location_samples.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_all_routes.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_today_routes.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_visit_data.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_route.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_route_last_synced_at.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_location_sample.dart';
import 'package:steelforce/features/my_visits/domain/usecases/run_route_delta_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/run_route_initial_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_route_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_workflow_step.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_all_routes.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_today_routes.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/ad_hoc_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/location_tracking_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_dashboard_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/stop_dashboard_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/resumable_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/today_call_plan_count_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/depot_selection_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/depot_stock_count_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_cubit.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_stop_information_repository.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/stop_information_cubit.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/features/my_visits/data/session/visit_unsent_work_source.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/discard_pending_visit_stop.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';
import 'package:steelforce/features/my_visits/data/local/check_out_reason_store.dart';
import 'package:steelforce/features/my_visits/data/remote/api_visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/check_out_reason_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/repositories/check_out_reason_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_reasons.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_in.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_out.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/check_out_reasons_cubit.dart';

/// Registers the route-management feature: GPS tracking, geofence
/// check-in/out, offline visit capture, and the route sync engine.
///
/// Still `Future`-returning after the T1.5b cutover even though nothing is
/// awaited here any more — see the matching note on `registerOrderFeature`.
Future<void> registerMyVisitsFeature(GetIt sl) async {
  // ── Data sources ────────────────────────────────────────────────────
  // Live by default. The old bundled route fixtures were removed because a
  // fixed set is wrong the moment the calendar moves and a mock that always
  // answers made a broken feed look healthy. The demo sources below answer
  // neither way: their routes are built against the clock, and they fail
  // like the live API whenever the demo is switched offline (`DemoNetwork`).
  //
  // TODO(release-gate): the `Demo*` sources, `DemoVisitLedger` and
  // `DemoLocationTrackingService` are demo-only, selected only when
  // `DataSourceMode.useMocks`. A live build never constructs them.
  if (DataSourceMode.useMocks) {
    // The demo backend's shared memory: an online check-in, the same row in
    // a later push, and the next route pull all read one ledger.
    sl.registerLazySingleton<DemoVisitLedger>(() => DemoVisitLedger());
  }
  sl.registerLazySingleton<RouteRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiRouteRemoteDataSource(sl<Dio>())
        : DemoRouteRemoteDataSource(sl<DemoNetwork>(), sl<DemoVisitLedger>()),
  );
  sl.registerLazySingleton<RouteLocalDataSource>(
      () => RouteDriftLocalDataSource(sl<AppDatabase>().routeDao, sl()));
  sl.registerLazySingleton<VisitLocalDataSource>(
      () => VisitDriftLocalDataSource(sl<AppDatabase>().visitDao, sl()));
  // T1.5 cutover: telemetry now reads/writes the encrypted Drift database
  // instead of the plaintext `routes.db`. The interface is unchanged, so the
  // repository and everything above it are untouched (ADR-003 seam).
  // `LocationSampleLocalDataSourceImpl` (sqflite) is retained but unregistered
  // until the import is verified in production — do not delete it before then
  // (`docs/skills/ai-engineering-playbook.md` §8: parity first).
  sl.registerLazySingleton<LocationSampleLocalDataSource>(() =>
      LocationSampleDriftLocalDataSource(sl<AppDatabase>().routeTelemetryDao));
  sl.registerLazySingleton<WorkflowStateLocalDataSource>(() =>
      WorkflowStateLocalDataSourceImpl(sl<AppDatabase>().workflowStateDao));
  // The live push is the one to trust for rejected/pending handling; the
  // demo push answers only while the demo is online, so the queue and the
  // drain are still what a presenter sees.
  sl.registerLazySingleton<VisitSyncRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiVisitSyncRemoteDataSource(sl<Dio>())
        : DemoVisitSyncRemoteDataSource(
            sl<DemoNetwork>(), sl<DemoVisitLedger>()),
  );
  // Check-in / check-out and the "no order" reasons
  // (check-in-check-out-mobile.md).
  sl.registerLazySingleton<VisitCheckRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiVisitCheckRemoteDataSource(sl<Dio>())
        : DemoVisitCheckRemoteDataSource(
            sl<DemoNetwork>(), sl<DemoVisitLedger>()),
  );
  sl.registerLazySingleton(() => CheckOutReasonStore(HiveService.cacheBox));
  // Ad hoc visits: the one operation that genuinely requires connectivity
  // (the server owns stop ids). The demo source refuses while the demo is
  // offline, so the queue and replay behaviour still show.
  sl.registerLazySingleton<AdHocVisitRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiAdHocVisitRemoteDataSource(sl<Dio>())
        : DemoAdHocVisitRemoteDataSource(
            sl<DemoNetwork>(), sl<DemoVisitLedger>()),
  );

  // ── Services ────────────────────────────────────────────────────────
  // TODO(release-gate): demo-only GPS — a fixed fix at today's first demo
  // stop, no permission prompt. Selected only when `DataSourceMode.useMocks`.
  sl.registerLazySingleton<LocationTrackingService>(
    () => DataSourceMode.useLiveApi
        ? GeolocatorTrackingService()
        : DemoLocationTrackingService() as LocationTrackingService,
  );
  sl.registerLazySingleton<LocationFixProvider>(
      () => sl<LocationTrackingService>() as LocationFixProvider);

  // Instantiate immediately so it listens to auth state changes
  sl.registerSingleton<LocationHeartbeatService>(
    LocationHeartbeatService(
      trackingService: sl(),
      authRemoteDataSource: sl(),
      sessionManager: sl(),
      logger: sl(),
    ),
  );

  sl.registerLazySingleton<FraudDetectionService>(
      () => const FraudDetectionService());
  sl.registerLazySingleton<StopDistanceSorter>(
      () => const StopDistanceSorter());
  sl.registerLazySingleton<ProofPhotoService>(
      () => CameraProofPhotoService(sl<ImageCaptureService>()));

  // ── Repositories ────────────────────────────────────────────────────
  sl.registerLazySingleton<RouteRepository>(() => RouteRepositoryImpl(sl()));
  // `onQueued` wakes the sync engine, resolved lazily because the engine is
  // registered after every feature.
  // Online, a check-in / check-out is offered to the server straight away;
  // anything short of a definite answer leaves it queued, and `onQueued`
  // wakes the sync engine (resolved lazily — it is registered after every
  // feature).
  sl.registerLazySingleton<VisitRepository>(() => VisitRepositoryImpl(
        sl(),
        remote: sl(),
        network: sl<NetworkInfo>(),
        logger: sl<AppLogger>(),
        onQueued: () {
          if (sl.isRegistered<SyncEngine>()) sl<SyncEngine>().requestSync();
        },
      ));
  sl.registerLazySingleton<CheckOutReasonRepository>(
    () => CheckOutReasonRepositoryImpl(
      remote: sl(),
      store: sl(),
      network: sl<NetworkInfo>(),
      logger: sl<AppLogger>(),
    ),
  );
  sl.registerLazySingleton<LocationSampleRepository>(
      () => LocationSampleRepositoryImpl(sl()));
  sl.registerLazySingleton<RouteSyncRepository>(
    () => RouteSyncRepositoryImpl(
        remote: sl(),
        local: sl(),
        network: sl<NetworkInfo>(),
        logger: sl<AppLogger>()),
  );
  sl.registerLazySingleton<VisitSyncRepository>(
    () => VisitSyncRepositoryImpl(
      remote: sl(),
      local: sl(),
      network: sl<NetworkInfo>(),
      logger: sl<AppLogger>(),
      // Quotations and orders queued at the shop go out between the
      // check-ins and the check-outs.
      sendBeforeCaptures: () async {
        if (!sl.isRegistered<UnsentWorkService>()) return;
        await sl<UnsentWorkService>().sendBefore(VisitUnsentWorkSource.name);
      },
    ),
  );
  sl.registerLazySingleton<ActiveWorkflowRepository>(
      () => ActiveWorkflowRepositoryImpl(sl()));
  // Reaches the DAO directly rather than through RouteLocalDataSource: the ad
  // hoc outbox is its own table with its own lifecycle, and widening the route
  // data source with queue methods would put an outbox behind an interface
  // named for reading plans.
  sl.registerLazySingleton<AdHocVisitRepository>(
    () => AdHocVisitRepositoryImpl(
      remote: sl(),
      dao: sl<AppDatabase>().routeDao,
      network: sl<NetworkInfo>(),
      logger: sl<AppLogger>(),
    ),
  );

  // ── Use cases ───────────────────────────────────────────────────────
  sl.registerLazySingleton(() => FetchTodayRoutes(sl()));
  sl.registerLazySingleton(() => FetchAllRoutes(sl()));
  sl.registerLazySingleton(() => WatchTodayRoutes(sl()));
  sl.registerLazySingleton(() => WatchAllRoutes(sl()));
  sl.registerLazySingleton(() => GetRoute(sl()));
  sl.registerLazySingleton(() => UpdateRouteStatus(sl()));
  sl.registerLazySingleton(() => UpdateStopStatus(sl()));

  sl.registerLazySingleton(() => CheckIn(sl()));
  sl.registerLazySingleton(() => CheckOut(sl()));
  sl.registerLazySingleton(() => AddOrderLine(sl()));
  sl.registerLazySingleton(() => AddStockUpdate(sl()));
  sl.registerLazySingleton(() => AddReturn(sl()));
  sl.registerLazySingleton(() => AddCollection(sl()));
  sl.registerLazySingleton(() => AddVisitNote(sl()));
  sl.registerLazySingleton(() => AddVisitPhoto(sl()));
  sl.registerLazySingleton(() => FetchVisitData(sl()));

  sl.registerLazySingleton(() => RecordLocationSample(sl()));
  sl.registerLazySingleton(() => FetchLocationSamples(sl()));
  sl.registerLazySingleton(() => RecordFraudFlag(sl()));

  sl.registerLazySingleton(() => RunRouteInitialSync(sl()));
  sl.registerLazySingleton(() => RunRouteDeltaSync(sl()));
  sl.registerLazySingleton(() => GetRouteLastSyncedAt(sl()));
  sl.registerLazySingleton(() => PushPendingVisitData(sl()));
  sl.registerLazySingleton(() => GetPendingVisitSync(sl()));
  sl.registerLazySingleton(() => DiscardPendingVisitStop(sl(), sl()));
  // A factory: the Sync Center sheet creates and closes one each time it
  // opens.
  sl.registerFactory(() {
    final engine = sl.isRegistered<SyncEngine>() ? sl<SyncEngine>() : null;
    return PendingVisitSyncCubit(
      getPendingVisitSync: sl(),
      discardPendingVisitStop: sl(),
      syncRunning: engine?.running,
      syncRunningNow: engine?.isRunning ?? false,
      // The same drain the Sync Center's "Sync Now" runs, in the same order:
      // depots, check-ins, quotations/orders, then check-outs and captures.
      syncNow: engine?.runNow,
      // The resume card is a long-lived singleton that only re-reads on
      // demand; a discarded check-in must not leave it offering the visit.
      onStopDiscarded: () => sl<ResumableVisitCubit>().refresh(),
    );
  });

  sl.registerLazySingleton(() => AddAdHocVisit(sl()));
  sl.registerLazySingleton(() => DrainAdHocVisitQueue(sl()));
  sl.registerLazySingleton(() => GetDepotIdsOnDay(sl()));
  sl.registerLazySingleton(() => WatchPendingAdHocVisits(sl()));

  sl.registerLazySingleton(() => SaveActiveWorkflow(sl()));
  sl.registerLazySingleton(() => ClearActiveWorkflow(sl()));
  sl.registerLazySingleton(() => GetActiveWorkflow(sl()));
  sl.registerLazySingleton(() => GetResumableRoute(sl(), sl()));
  // Write-side for business-task transitions (Quotation/Sales Order/…): records
  // the current workflow + screen + navigation args onto the active pointer so
  // the resume dispatcher can restore the exact screen.
  sl.registerLazySingleton(() => UpdateWorkflowStep(sl()));
  // Deferred check-out: closes the visit off the persisted pointer (no live
  // ActiveRouteBloc needed) — triggered by the explicit "Check out" on the
  // Continue-Working card now that Stock Count no longer auto-checks-out.
  sl.registerLazySingleton(() => CompleteVisitCheckOut(
        sl(),
        sl(),
        sl(),
        sl(),
        sl<AppLogger>(),
        sl<FetchLocationSamples>(),
        sl<VisitRepository>(),
        sl<SendCheckOut>(),
      ));
  sl.registerLazySingleton(() => SendCheckIn(sl()));
  sl.registerLazySingleton(() => SendCheckOut(sl()));
  sl.registerLazySingleton(() => GetCheckOutReasons(sl()));
  sl.registerFactory(() => CheckOutReasonsCubit(sl()));
  // Reads the Order feature's quotations through its domain interface.
  sl.registerLazySingleton(
      () => GetCheckOutContext(sl(), sl(), sl<QuotationRepository>()));

  // ── Presentation ────────────────────────────────────────────────────
  // Reads the depots feature's domain interface, never its data layer.
  sl.registerFactory(
      () => StopInformationCubit(sl<DepotStopInformationRepository>()));

  sl.registerFactory(() => RouteDashboardCubit(watchAllRoutes: sl()));
  sl.registerFactory(() => AdHocVisitCubit(
        addAdHocVisit: sl(),
        drainQueue: sl(),
        depotIdsOnDay: sl(),
        watchPending: sl(),
      ));
  // Stop-centric dashboard: multi-day (calendar) stops sorted nearest-first by
  // live GPS, with a planned-order fallback when location is unavailable.
  sl.registerFactory(() => StopDashboardCubit(
        watchAllRoutes: sl(),
        fetchAllRoutes: sl(),
        locationService: sl(),
        sorter: sl(),
      ));
  sl.registerFactory(() => ActiveRouteBloc(
        saveActiveWorkflow: sl(),
        clearActiveWorkflow: sl(),
        getActiveWorkflow: sl(),
        getRoute: sl(),
        updateRouteStatus: sl(),
        updateStopStatus: sl(),
        checkIn: sl(),
        checkOut: sl(),
        recordFraudFlag: sl(),
        fraudDetectionService: sl(),
        sendCheckIn: sl(),
      ));
  sl.registerFactory(() => LocationTrackingCubit(
        trackingService: sl(),
        recordLocationSample: sl(),
        recordFraudFlag: sl(),
        fraudDetectionService: sl(),
      ));
  sl.registerFactory(() => VisitCubit(
        fetchVisitData: sl(),
        addOrderLine: sl(),
        addStockUpdate: sl(),
        addReturn: sl(),
        addCollection: sl(),
        addVisitNote: sl(),
        addVisitPhoto: sl(),
      ));
  sl.registerFactory(() => RouteSyncCubit(
        pushPendingVisitData: sl(),
        runInitialSync: sl(),
        runDeltaSync: sl(),
        getLastSyncedAt: sl(),
        // Depot-directory guard (ADR-001 FK ordering): resolved lazily at
        // cubit creation, so registration order vs. the depots feature
        // doesn't matter.
        runDepotInitialSync: sl(),
        getDepotLastSyncedAt: sl(),
        browseDepots: sl(),
        sessionManager: sl<SessionManager>(),
      ));

  // Lazy singleton (not a factory): its "resume this check-in" state must
  // survive tab switches and be refreshable from the shell.
  sl.registerLazySingleton(() => ResumableVisitCubit(
        getResumableRoute: sl(),
        getRoute: sl(),
        getActiveWorkflow: sl(),
        clearActiveWorkflow: sl(),
        completeVisitCheckOut: sl(),
      ));

  // Home "My Visits" badge. A factory: the Home grid owns and closes it, so a
  // sign-out that tears down the shell leaves no rep's count behind.
  sl.registerFactory(() => TodayCallPlanCountCubit(
        watchTodayRoutes: sl(),
        fetchTodayRoutes: sl(),
      ));

  // ── Depot Stock flow ────────────────────────────────────────────────
  sl.registerLazySingleton(() => DepotSelectionStore(HiveService.cacheBox));
  sl.registerFactory(
      () => DepotSelectionCubit(browseDepots: sl(), store: sl()));
  sl.registerFactory(() => DepotStockCountCubit(
        getDepotById: sl(),
        browseProducts: sl(),
        addStockUpdate: sl(),
        runInitialSync: sl(),
        sessionManager: sl<SessionManager>(),
      ));
}
