import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/sync/offline_data_prefetcher.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/authentication/domain/usecases/refresh_profile.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_cubit.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_reasons.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_my_visit_plans.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_today_visit_plans.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_sync_cubit.dart';
import 'package:steelforce/features/notification/domain/usecases/inbox_usecases.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';

/// What the signed-in shell pulls onto the device so the rep can work offline
/// (`OfflineDataPrefetcher`). Each entry reuses the feature's own pull — the
/// same one its screen runs — so permission gates, initial-vs-delta and local
/// storage stay in one place.
///
/// Lives in the composition root, not in `core/sync`, because it names
/// features; the prefetcher itself knows none of them.
List<OfflineDataSource> offlineDataSources(GetIt sl) => [
      // Depots, then routes: a route's stops point at depots (ADR-001 FK
      // ordering), and running both at once would pull the depot directory
      // twice on a first install.
      CallbackOfflineDataSource('depots_and_routes', () async {
        await _closing(sl<DepotSyncCubit>(), (c) => c.syncIfNeeded());
        await _closing(sl<RouteSyncCubit>(), (c) => c.syncIfNeeded());
      }),
      CallbackOfflineDataSource(
          'catalog', () => _closing(sl<SyncCubit>(), (c) => c.syncIfNeeded())),
      // Each read saves the device's copy (`VisitPlanRepositoryImpl`).
      CallbackOfflineDataSource('visit_plans', () async {
        _throwOn(await sl<GetTodayVisitPlans>()(const NoParams()));
        _throwOn(await sl<GetMyVisitPlans>()(PlanPeriod.thisMonth));
      }),
      CallbackOfflineDataSource('profile',
          () async => _throwOn(await sl<RefreshProfile>()(const NoParams()))),
      CallbackOfflineDataSource('check_out_reasons',
          () => sl<GetCheckOutReasons>()(const NoParams())),
      CallbackOfflineDataSource(
          'notifications',
          () async => _throwOn(
              await sl<SyncNotifications>()(SyncNotificationsParams.delta))),
    ];

/// Runs [body] on a freshly created [cubit] and always closes it: these are
/// factories, and nothing else will.
Future<void> _closing<C extends BlocBase<Object?>>(
    C cubit, Future<void> Function(C cubit) body) async {
  try {
    await body(cubit);
  } finally {
    await cubit.close();
  }
}

/// Turns a failed result into an error so the prefetcher logs that source as
/// failed rather than done.
void _throwOn(Result<Object?> result) {
  if (result case Failed(:final failure)) throw failure;
}
