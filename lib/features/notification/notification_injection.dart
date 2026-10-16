import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/notifications/local/local_notification_presenter.dart';
import 'package:steelforce/core/notifications/local/local_notification_presenter_factory.dart'
    as local_platform;
import 'package:steelforce/core/notifications/local/local_notification_presenter_web.dart'
    show NoopLocalNotificationPresenter;
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service_factory.dart'
    as push_platform;
import 'package:steelforce/core/notifications/push/push_messaging_service_web.dart'
    show UnsupportedPushMessagingService;
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/notification/data/remote/api_notification_remote_data_source.dart';
import 'package:steelforce/features/notification/data/remote/mock_notification_remote_data_source.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/data/repositories/notification_inbox_repository_impl.dart';
import 'package:steelforce/features/notification/data/repositories/notification_preferences_repository_impl.dart';
import 'package:steelforce/features/notification/data/repositories/push_device_repository_impl.dart';
import 'package:steelforce/features/notification/domain/repositories/notification_inbox_repository.dart';
import 'package:steelforce/features/notification/domain/repositories/notification_preferences_repository.dart';
import 'package:steelforce/features/notification/domain/repositories/push_device_repository.dart';
import 'package:steelforce/features/notification/domain/usecases/inbox_usecases.dart';
import 'package:steelforce/features/notification/domain/usecases/preferences_usecases.dart';
import 'package:steelforce/features/notification/domain/usecases/push_device_usecases.dart';
import 'package:steelforce/features/authentication/domain/notification_lifecycle.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/notification/notification_coordinator.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_badge_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_preferences_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/push_permission_cubit.dart';

/// Registers the notification feature
/// (`docs/feature/notification/README.md`).
///
/// ## Ordering
///
/// Must run **after** `registerAuthFeature`, which supplies the authenticated
/// `Dio` and `DeviceIdentity`. Registration is lazy so ordering only matters for
/// resolution, not for this call — but the device identity in particular is
/// load-bearing: §4.2 makes `deviceId` the upsert key for a registration, and
/// reusing the one auth already mints keeps a handset to a single identity
/// across the session list and the device registry.
///
/// ## Why the badge cubit is a singleton and the rest are factories
///
/// [NotificationBadgeCubit] backs the app-bar bell, which is rebuilt on every
/// tab change, and the same figures appear in the sheet. A factory would open a
/// fresh Drift stream per rebuild, leak one per discarded app bar, and let two
/// surfaces briefly disagree — which is how a badge stops being believed. The
/// inbox and preferences cubits are per-screen and are closed by the screens
/// that build them.
void registerNotificationFeature(GetIt sl) {
  // ── Platform transports ─────────────────────────────────────────────
  //
  // Both are conditional-export factories: the native ones on Android/iOS, and
  // honest no-ops on web (ADR-010 — a browser build ships no service worker or
  // VAPID key, and `flutter_local_notifications` has no web implementation at
  // all). Nothing above these needs a `kIsWeb` branch, and the inbox is
  // unaffected either way, which is the §1 design in one line.
  //
  // TODO(release-gate): a demo build (`USE_MOCK_DATA=true`) takes the web
  // no-ops on every platform, so `Firebase.initializeApp` never runs and no
  // FCM traffic leaves the device. The inbox is unaffected — it syncs from the
  // demo source either way.
  sl.registerLazySingleton<PushMessagingService>(
    () => DataSourceMode.useLiveApi
        ? push_platform.createPushMessagingService(sl<AppLogger>())
        : UnsupportedPushMessagingService(sl<AppLogger>()),
  );
  sl.registerLazySingleton<LocalNotificationPresenter>(
    () => DataSourceMode.useLiveApi
        ? local_platform.createLocalNotificationPresenter(sl<AppLogger>())
        : NoopLocalNotificationPresenter(sl<AppLogger>()),
  );

  // Holds a deep link that arrived before it could be opened — a cold start
  // during bootstrap, or a tap on an expired session (§10).
  sl.registerLazySingleton<PendingNotificationLink>(
      () => PendingNotificationLink());

  // ── Data sources ────────────────────────────────────────────────────
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiNotificationRemoteDataSource(sl<Dio>())
        : MockNotificationRemoteDataSource(network: sl<DemoNetwork>()),
  );

  // ── Repositories ────────────────────────────────────────────────────
  sl.registerLazySingleton<NotificationInboxRepository>(
    () => NotificationInboxRepositoryImpl(
      // The DAO directly, per ADR-004 — every local read and write goes through
      // a generated Drift DAO. There is no separate local data source because
      // the DAO already *is* the narrow, injectable seam, and drift's in-memory
      // database makes it testable without one.
      dao: sl<AppDatabase>().notificationDao,
      remote: sl(),
      session: sl<SessionManager>(),
      logger: sl<AppLogger>(),
    ),
  );
  sl.registerLazySingleton<PushDeviceRepository>(
    () => PushDeviceRepositoryImpl(
      messaging: sl(),
      remote: sl(),
      identity: sl(),
      session: sl<SessionManager>(),
      logger: sl<AppLogger>(),
      getFixProvider: () => sl.isRegistered<LocationFixProvider>()
          ? sl<LocationFixProvider>()
          : null,
    ),
  );
  sl.registerLazySingleton<NotificationPreferencesRepository>(
    () => NotificationPreferencesRepositoryImpl(
      remote: sl(),
      // Hive, not the encrypted database: these are the rep's own toggles —
      // settings, regenerable from the server — rather than business records or
      // PII (`docs/blueprint/system-architecture.md` §3). The notifications themselves *are*
      // encrypted, because a title names a depot and a route.
      cache: LocalCache(HiveService.cacheBox),
      session: sl<SessionManager>(),
      logger: sl<AppLogger>(),
    ),
  );

  // ── Use cases ───────────────────────────────────────────────────────
  sl.registerLazySingleton(() => WatchNotifications(sl()));
  sl.registerLazySingleton(() => WatchNotificationCounts(sl()));
  sl.registerLazySingleton(() => GetNotificationById(sl()));
  sl.registerLazySingleton(() => SyncNotifications(sl()));
  sl.registerLazySingleton(() => RefreshNotificationCounts(sl()));
  sl.registerLazySingleton(() => MarkNotificationRead(sl()));
  sl.registerLazySingleton(() => MarkAllNotificationsRead(sl()));
  sl.registerLazySingleton(() => RecordNotificationAction(sl()));
  sl.registerLazySingleton(() => DismissNotification(sl()));
  sl.registerLazySingleton(() => DrainNotificationActions(sl()));
  sl.registerLazySingleton(() => IngestPushNotification(sl()));
  sl.registerLazySingleton(() => ClearNotifications(sl()));

  sl.registerLazySingleton(() => RegisterPushDevice(sl()));
  sl.registerLazySingleton(() => DeregisterPushDevice(sl()));
  sl.registerLazySingleton(() => RequestPushPermission(sl()));
  sl.registerLazySingleton(() => GetPushPermissionStatus(sl()));

  sl.registerLazySingleton(() => LoadNotificationPreferences(sl()));
  sl.registerLazySingleton(() => GetCachedNotificationPreferences(sl()));
  sl.registerLazySingleton(() => SaveNotificationPreferences(sl()));
  sl.registerLazySingleton(() => ClearNotificationPreferences(sl()));

  // ── Orchestration ───────────────────────────────────────────────────
  //
  // One place holding the whole §16 startup checklist, so a reviewer can read it
  // against the spec line by line rather than hunting for five separate hooks
  // that each fail silently when missed.
  sl.registerLazySingleton<NotificationCoordinator>(
    () => NotificationCoordinator(
      messaging: sl(),
      presenter: sl(),
      connectivity: sl<ConnectivityService>(),
      session: sl<SessionManager>(),
      pendingLink: sl(),
      syncNotifications: sl(),
      refreshCounts: sl(),
      drainActions: sl(),
      ingestPush: sl(),
      clearNotifications: sl(),
      registerDevice: sl(),
      deregisterDevice: sl(),
      clearPreferences: sl(),
      logger: sl<AppLogger>(),
    ),
  );

  // Exposed to authentication under its own narrow interface, so `AuthBloc` can
  // deregister this installation *before* the access token is discarded (§4.4)
  // without importing this feature's data layer.
  sl.registerLazySingleton<NotificationLifecycle>(
      () => sl<NotificationCoordinator>());

  // ── Presentation ────────────────────────────────────────────────────
  sl.registerLazySingleton(
    () => NotificationBadgeCubit(watchCounts: sl(), refreshCounts: sl()),
  );

  sl.registerFactory(
    () => NotificationInboxCubit(
      watchNotifications: sl(),
      syncNotifications: sl(),
      markRead: sl(),
      markAllRead: sl(),
      recordAction: sl(),
      dismissNotification: sl(),
      // A function rather than a use case: this calls *another* feature's
      // endpoint, chosen by the server (§12). Wrapping it in a notification use
      // case would imply the notification domain owns route acknowledgement and
      // quotation approval, which it does not.
      invokeAction: ({required endpoint, required method}) =>
          sl<NotificationRemoteDataSource>()
              .invokeAction(endpoint: endpoint, method: method),
    ),
  );

  sl.registerFactory(
    () => PushPermissionCubit(
      getStatus: sl(),
      requestPermission: sl(),
      cache: LocalCache(HiveService.cacheBox),
    ),
  );

  sl.registerFactory(
    () => NotificationPreferencesCubit(load: sl(), cached: sl(), save: sl()),
  );
}
