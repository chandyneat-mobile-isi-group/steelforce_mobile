import 'package:get_it/get_it.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/location_sample_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_sync_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_ad_hoc_visit_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_location_sample_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_route_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_route_sync_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_visit_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_visit_sync_repository.dart';

/// Registers the visit lesson's stand-ins into the practice scope.
///
/// Called by `registerMyVisitsFeature`'s practice contribution, immediately
/// before the use cases are re-registered over them. Each real repository is
/// resolved **first** — after its stand-in is registered, `sl<T>()` answers
/// with the stand-in.
///
/// ## What the lesson's visit touches, and where it goes instead
///
/// | Write | Real home | During practice |
/// |---|---|---|
/// | route/stop status | Drift `routes` | [PracticeRouteRepository] |
/// | check-in / check-out / photos / notes | Drift visit tables + sync queue | [PracticeVisitRepository] |
/// | `POST /visits/check-ins`, `/check-outs` | API | answered "sent" in memory |
/// | resume pointer | Drift `workflow_state` | [PracticeActiveWorkflowRepository] |
/// | GPS samples, fraud flags | Drift telemetry | [PracticeLocationSampleRepository] |
/// | ad hoc visit request | API + Drift outbox | [PracticeAdHocVisitRepository] |
/// | visit push, route pull | API | [PracticeVisitSyncRepository], [PracticeRouteSyncRepository] |
///
/// ## What is deliberately *not* replaced
///
/// * `ResumableVisitCubit` and the sync engine — long-lived singletons built
///   from the real scope before any lesson starts, so they only ever see real
///   stores, and the practice visit never appears on Home's continue card.
/// * `LocationTrackingService` and `ProofPhotoService` — the lesson reads the
///   device's real position (screen-scoped, never persisted for the practice
///   route) and uses the real camera; photo files are deleted with the lesson.
/// * `CheckOutReasonRepository` — reference data (the "no order" reasons), not
///   a record of the visit.
void registerMyVisitsPractice(GetIt sl, PracticeWorld world) {
  final routes = sl<RouteRepository>();
  final visits = sl<VisitRepository>();
  final workflows = sl<ActiveWorkflowRepository>();
  final telemetry = sl<LocationSampleRepository>();
  final adHoc = sl<AdHocVisitRepository>();
  final visitSync = sl<VisitSyncRepository>();
  final routeSync = sl<RouteSyncRepository>();

  sl.registerLazySingleton<RouteRepository>(
      () => PracticeRouteRepository(routes, world));
  sl.registerLazySingleton<VisitRepository>(
      () => PracticeVisitRepository(visits, world));
  sl.registerLazySingleton<ActiveWorkflowRepository>(
      () => PracticeActiveWorkflowRepository(workflows, world));
  sl.registerLazySingleton<LocationSampleRepository>(
      () => PracticeLocationSampleRepository(telemetry, world));
  sl.registerLazySingleton<AdHocVisitRepository>(
      () => PracticeAdHocVisitRepository(adHoc, world));
  sl.registerLazySingleton<VisitSyncRepository>(
      () => PracticeVisitSyncRepository(visitSync, world));
  sl.registerLazySingleton<RouteSyncRepository>(
      () => PracticeRouteSyncRepository(routeSync, world));
}
