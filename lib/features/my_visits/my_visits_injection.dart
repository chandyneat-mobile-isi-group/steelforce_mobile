import 'package:get_it/get_it.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_pending_plan_visits.dart';
import 'package:steelforce/features/my_visits/domain/repositories/pending_plan_visits_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_visit_pending_reader.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/session/location_heartbeat_service.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/my_visits/data/local/depot_selection_store.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/route_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/workflow_state_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_plan_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_my_visit_plans.dart';
import 'package:steelforce/features/my_visits/domain/usecases/skip_visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/start_ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/plan_visit_steps_held.dart';
import 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_store.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_visit_outbox_sender.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_visit_steps.dart';
import 'package:steelforce/features/my_visits/data/local/visit_plan_local_data_source.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_in_visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out_visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/upload_plan_inventory_photos.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_plan_check_in_target.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_today_visit_plans.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plan_calendar_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plans_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/plan_check_in_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/plan_check_out_cubit.dart';
import 'package:steelforce/features/my_visits/data/repositories/active_workflow_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/ad_hoc_visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/location_sample_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/my_visits_remote_sources.dart';
import 'package:steelforce/features/my_visits/practice/my_visits_practice.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/location_sample_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_sync_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/services/stop_distance_sorter.dart';
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
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/active_plan_visit_cubit.dart';
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
import 'package:steelforce/features/my_visits/data/repositories/check_out_reason_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/repositories/check_out_reason_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_reasons.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_in.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_out.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/check_out_reasons_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/visit_plan_day_request.dart';
import 'package:steelforce/features/my_visits/data/local/plan_inventory_log.dart';
import 'package:steelforce/features/my_visits/domain/usecases/is_plan_inventory_done.dart';

/// Registers the route-management feature: GPS tracking, geofence
/// check-in/out, offline visit capture, and the route sync engine.
///
/// Still `Future`-returning after the T1.5b cutover even though nothing is
/// awaited here any more — see the matching note on `registerOrderFeature`.
Future<void> registerMyVisitsFeature(GetIt sl) async {
  // ── Data sources ────────────────────────────────────────────────────
  // Remote sources and GPS: live, or the in-memory demo set under
  // `USE_MOCK_DATA=true` (the static web demo).
  registerMyVisitsRemoteSources(sl);
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
  sl.registerLazySingleton(() => CheckOutReasonStore(HiveService.cacheBox));

  // ── Services ────────────────────────────────────────────────────────
  // Instantiate immediately so it listens to auth state changes
  sl.registerSingleton<LocationHeartbeatService>(
    LocationHeartbeatService(
      trackingService: sl(),
      locationFixProvider: sl<LocationFixProvider>(),
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
  registerMyVisitsUseCases(sl);

  // ── Practice ────────────────────────────────────────────────────────
  // The same use cases again, inside the practice scope, over in-memory
  // stand-ins — so a lesson walks the real visit screens and blocs without
  // a record reaching Drift, the sync queue or the API.
  if (sl.isRegistered<PracticeSession>()) {
    sl<PracticeSession>().contribute((scope, world) {
      registerMyVisitsPractice(scope, world);
      registerMyVisitsUseCases(scope);
    });
  }

  // ── Presentation ────────────────────────────────────────────────────
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
  sl.registerFactory(() => CheckOutReasonsCubit(sl()));

  // Visit plans (`GET /api/v1/mobile/plans`; remote source registered with
  // the others above). Registered here rather than in
  // `registerMyVisitsUseCases`: practice scopes have no plan repository of
  // their own, and the root one is the only source.
  sl.registerLazySingleton<VisitPlanLocalDataSource>(
      () => DriftVisitPlanLocalDataSource(sl<AppDatabase>().visitPlanDao));
  // Check-in, inventory photos and check-out worked offline wait here, and
  // the sync engine sends them in order (resolved lazily — it is registered
  // after every feature).
  sl.registerLazySingleton(
      () => PlanVisitOutboxStore(sl<AppDatabase>().visitPlanDao));
  sl.registerLazySingleton(() => PlanVisitOutboxSender(
      remote: sl(), store: sl(), logger: sl<AppLogger>()));
  sl.registerLazySingleton<VisitPlanRepository>(() => VisitPlanRepositoryImpl(
        remote: sl(),
        network: sl<NetworkInfo>(),
        local: sl(),
        inventory: PlanInventoryLog(
            box: HiveService.cacheBox, store: sl<PlanVisitOutboxStore>()),
        steps: PlanVisitSteps(
          store: sl(),
          sender: sl(),
          network: sl<NetworkInfo>(),
          remote: sl(),
          local: sl(),
          onQueued: () {
            if (sl.isRegistered<SyncEngine>()) sl<SyncEngine>().requestSync();
          },
        ),
      ));
  sl.registerLazySingleton(() => GetMyVisitPlans(sl()));
  sl.registerLazySingleton(() => GetTodayVisitPlans(sl()));
  sl.registerLazySingleton(() => SkipVisitPlan(sl()));
  sl.registerLazySingleton(() => GetPlanCheckInTarget(sl()));
  sl.registerLazySingleton(() => CheckInVisitPlan(sl()));
  sl.registerLazySingleton(() => UploadPlanInventoryPhotos(sl()));
  sl.registerLazySingleton(() => CheckOutVisitPlan(sl()));
  sl.registerLazySingleton(() => ResendPlanVisitSteps(sl()));
  sl.registerLazySingleton(() => DiscardPlanVisitSteps(sl()));
  // The Sync Center's "Planned visits": the same outbox, one entry a visit.
  sl.registerLazySingleton<PendingPlanVisitsSource>(
      () => PlanVisitPendingReader(store: sl(), local: sl()));
  sl.registerLazySingleton(() => WatchPendingPlanVisits(sl()));
  sl.registerFactory(
      () => PendingPlanVisitsCubit(watch: sl(), resend: sl(), discard: sl()));
  sl.registerLazySingleton(() => StartAdHocPlan(sl()));
  sl.registerFactory(() => PlanCheckInCubit(
        getTarget: sl(),
        checkIn: sl(),
        location: sl<LocationFixProvider>(),
        logger: sl<AppLogger>(),
      ));
  sl.registerFactory(() => PlanCheckOutCubit(
        checkOut: sl(),
        location: sl<LocationFixProvider>(),
      ));
  // The Visits list reads `/plans/today`; its calendar reads `/plans`.
  sl.registerFactory(() => VisitPlansCubit(
      getTodayVisitPlans: sl(),
      skipVisitPlan: sl(),
      synced: _planStepsSynced(sl)));
  sl.registerFactory(() => VisitPlanCalendarCubit(
      getMyVisitPlans: sl(), synced: _planStepsSynced(sl)));

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
  sl.registerFactory(() => TodayCallPlanCountCubit(getTodayVisitPlans: sl()));

  // Home "Continue visit" for a checked-in plan. A factory for the same
  // reason: Home owns and closes it, so sign-out leaves no visit behind.
  sl.registerLazySingleton(() => IsPlanInventoryDone(sl()));
  sl.registerFactory(() =>
      ActivePlanVisitCubit(getTodayVisitPlans: sl(), isInventoryDone: sl()));

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

/// Every my_visits use case. Called once by [registerMyVisitsFeature] for the
/// real app, and again inside the practice scope, where each `sl()` resolves
/// the practice stand-ins registered just before it
/// (`practice/my_visits_practice.dart`).
///
/// Use cases only: blocs and cubits are factories, so they already resolve
/// these from whichever scope is current when a screen builds them.
void registerMyVisitsUseCases(GetIt sl) {
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
  sl.registerLazySingleton(VisitPlanDayRequest.new);
  // Reads the Order feature's quotations through its domain interface.
  sl.registerLazySingleton(
      () => GetCheckOutContext(sl(), sl(), sl<QuotationRepository>()));
}

/// Each sync drain, so the visit lists reload once offline steps went out.
/// Null where no engine runs (tests, practice).
Stream<Object?>? _planStepsSynced(GetIt sl) =>
    sl.isRegistered<SyncEngine>() ? sl<SyncEngine>().reports : null;
