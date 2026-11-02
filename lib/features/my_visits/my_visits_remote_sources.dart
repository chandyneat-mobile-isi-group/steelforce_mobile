import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_world.dart';
import 'package:steelforce/features/my_visits/data/remote/route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/services/demo_location_tracking_service.dart';
import 'package:steelforce/features/my_visits/data/services/geolocator_tracking_service.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';

/// My Visits' remote data sources and GPS: the live API and the device's
/// location by default, or the in-memory demo set when the build is compiled
/// with `USE_MOCK_DATA=true` ([DataSourceMode]) — the static web demo, which
/// has no backend. Everything above these (repositories, outboxes, Drift,
/// use cases, blocs) is the same in both.
void registerMyVisitsRemoteSources(GetIt sl) {
  final demo = DataSourceMode.useMocks;
  // TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
  // The demo backend's one memory: a plan checked in shows as checked in on
  // the Plans list, the route pull and a visit push alike.
  if (demo) sl.registerLazySingleton<MockVisitWorld>(() => MockVisitWorld());

  // Live: routes are rep- and day-scoped, so a committed fixture set is wrong
  // the moment the calendar moves. The demo builds its set against the clock.
  sl.registerLazySingleton<RouteRemoteDataSource>(() => demo
      ? MockRouteRemoteDataSource(sl<MockVisitWorld>())
      : ApiRouteRemoteDataSource(sl<Dio>()));
  // Live, the push endpoint is the one to trust for the rejected/pending
  // handling this feature depends on.
  sl.registerLazySingleton<VisitSyncRemoteDataSource>(() => demo
      ? MockVisitSyncRemoteDataSource(sl<MockVisitWorld>())
      : ApiVisitSyncRemoteDataSource(sl<Dio>()));
  // Check-in / check-out and the "no order" reasons
  // (check-in-check-out-mobile.md).
  sl.registerLazySingleton<VisitCheckRemoteDataSource>(() => demo
      ? MockVisitCheckRemoteDataSource(sl<MockVisitWorld>())
      : ApiVisitCheckRemoteDataSource(sl<Dio>()));
  // Ad hoc visits: live, the one operation that genuinely requires
  // connectivity (the server owns stop ids).
  sl.registerLazySingleton<AdHocVisitRemoteDataSource>(() => demo
      ? MockAdHocVisitRemoteDataSource(sl<MockVisitWorld>())
      : ApiAdHocVisitRemoteDataSource(sl<Dio>()));
  // Visit plans (`GET /api/v1/mobile/plans`).
  sl.registerLazySingleton<VisitPlanRemoteDataSource>(() => demo
      ? MockVisitPlanRemoteDataSource(sl<MockVisitWorld>())
      : ApiVisitPlanRemoteDataSource(sl<Dio>(), logger: sl<AppLogger>()));

  // TODO(release-gate): demo-only GPS, an anti-fraud bypass — a fixed fix and
  // no permission prompt; must never be registered in a release mobile build
  // (USE_MOCK_DATA=false).
  sl.registerLazySingleton<LocationTrackingService>(() => demo
      ? DemoLocationTrackingService() as LocationTrackingService
      : GeolocatorTrackingService());
  sl.registerLazySingleton<LocationFixProvider>(
      () => sl<LocationTrackingService>() as LocationFixProvider);
}
