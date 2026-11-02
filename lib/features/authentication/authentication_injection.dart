import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/database/drift/local_database_reset.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/platform/device/device_identity.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/interceptors/auth_interceptor.dart';
import 'package:steelforce/core/network/app_network.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/mock_auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/mock_phone_verification_data_sources.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_ownership_verifier.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_password_change_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_reset_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/secure_sign_in_memory.dart';
import 'package:steelforce/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:steelforce/features/authentication/data/repositories/phone_ownership_reset_repository_impl.dart';
import 'package:steelforce/features/authentication/data/repositories/phone_password_change_repository_impl.dart';
import 'package:steelforce/features/authentication/domain/notification_lifecycle.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_ownership_reset_repository.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_password_change_repository.dart';
import 'package:steelforce/features/authentication/domain/repositories/sign_in_memory.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_remembered_phone.dart';
import 'package:steelforce/features/authentication/domain/usecases/update_remembered_phone.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_current_user.dart';
import 'package:steelforce/features/authentication/domain/usecases/refresh_profile.dart';
import 'package:steelforce/features/authentication/domain/usecases/login.dart';
import 'package:steelforce/features/authentication/domain/usecases/logout.dart';
import 'package:steelforce/features/authentication/domain/usecases/phone_password_change.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/phone_password_change_cubit.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';

/// Registers every dependency the authentication feature needs.
/// Externals (secure storage, connectivity, network info) are registered
/// by the core composition root before this runs.
///
/// All registrations are lazy, so registration order is irrelevant — a
/// dependency is only built the first time it's resolved.
void registerAuthFeature(GetIt sl) {
  // ── Presentation ───────────────────────────────────────────────────
  // Factory: a fresh bloc per screen, disposed with it.
  sl.registerFactory(
    () => AuthBloc(
      login: sl(),
      logout: sl(),
      getCurrentUser: sl(),
      sessionManager: sl(),
      // Resolved lazily at bloc construction, which happens after every
      // feature has registered — auth is wired before order/my_visits, so an
      // eager reference here would not find their repositories yet.
      sessionReset: sl(),
      appRestart: sl(),
      repository: sl<AuthRepository>(),
      logger: sl<AppLogger>(),
      // Resolved at bloc construction — which happens after every feature has
      // registered — for the same reason `sessionReset` is: the notification
      // feature is wired after auth, so an eager reference here would not find
      // its coordinator yet.
      notifications: sl<NotificationLifecycle>(),
      // Core services registered after every feature, resolved here at bloc
      // construction for the same reason.
      unsentWork: sl<UnsentWorkService>(),
      dataOwnership: sl<LocalDataOwnership>(),
      updateRememberedPhone: sl(),
    ),
  );

  // Signed-in password change by SMS. A factory taking whether Firebase phone
  // auth exists on this build, so the cubit — and the phone proof it holds —
  // dies with its route.
  sl.registerFactoryParam<PhonePasswordChangeCubit, bool, void>(
    (available, _) => PhonePasswordChangeCubit(
      startVerification: sl(),
      verifyProof: sl(),
      changePassword: sl(),
      available: available,
    ),
  );

  // ── Domain (use cases) ─────────────────────────────────────────────
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => Logout(sl()));
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => RefreshProfile(sl()));
  sl.registerLazySingleton(() => GetRememberedPhone(sl()));
  sl.registerLazySingleton(() => UpdateRememberedPhone(sl()));
  sl.registerLazySingleton(() => StartOwnPhoneVerification(sl()));
  sl.registerLazySingleton(() => VerifyOwnPhoneProof(sl()));
  sl.registerLazySingleton(() => ChangePasswordWithPhoneProof(sl()));

  // ── Data (repository) ──────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remote: sl(),
      local: sl(),
      networkInfo: sl(),
      logger: sl<AppLogger>(),
    ),
  );

  // Password reset through Firebase Phone Auth. Lazy, and only resolved when
  // `AppConfig.passwordResetViaFirebase` routes a reset here — so a build with
  // the flag off, and the web build, never touch Firebase Auth.
  sl.registerLazySingleton<PhoneOwnershipResetRepository>(
    () => PhoneOwnershipResetRepositoryImpl(
      verifier: sl(),
      remote: sl(),
      networkInfo: sl(),
      logger: sl<AppLogger>(),
    ),
  );

  // Lazy for the same reason: only the signed-in change-password route
  // resolves it, and only where Firebase phone auth exists.
  sl.registerLazySingleton<PhonePasswordChangeRepository>(
    () => PhonePasswordChangeRepositoryImpl(
      verifier: sl(),
      remote: sl(),
      ownPhoneNumber: () async =>
          (await sl<AuthLocalDataSource>().readProfile())?.phoneNumber,
      networkInfo: sl(),
      logger: sl<AppLogger>(),
    ),
  );

  // ── Data (sources) ─────────────────────────────────────────────────
  // One concrete local source, exposed under two interfaces so the
  // interceptor and the repository share the exact same token storage.
  sl.registerLazySingleton(() => AuthLocalDataSourceImpl(sl()));
  sl.registerLazySingleton<AuthLocalDataSource>(
      () => sl<AuthLocalDataSourceImpl>());
  sl.registerLazySingleton<TokenStore>(() => sl<AuthLocalDataSourceImpl>());

  // "Remember me" — the phone number only, in secure storage.
  sl.registerLazySingleton<SignInMemory>(() => SecureSignInMemory(sl()));

  // The per-installation device identity sent with login and every refresh.
  // A singleton because the id must be the same value across both — minting a
  // second one would detach the rotation from the session it belongs to.
  sl.registerLazySingleton(() => DeviceIdentity(sl()));

  // Authenticated Dio client (auto token attach + refresh). The default `Dio`
  // registration, so feature data sources resolve it without extra ceremony.
  sl.registerLazySingleton<Dio>(
    () => AppNetwork.createAuthedClient(
      tokenStore: sl<TokenStore>(),
      deviceId: () => sl<DeviceIdentity>().deviceId(),
      logger: sl<AppLogger>(),
      // Closes the loop between the network layer and global session state.
      //
      // Without this the interceptor cleared the token store on a failed
      // refresh and nothing else in the app was told: `SessionManager` still
      // reported the user as authenticated, guards still let them into
      // protected screens, and every subsequent request failed with no
      // explanation. The session was gone but the app did not know it.
      onSessionExpired: () => sl<SessionManager>().expire(),
      // The rep's offline choice, enforced for every feature data source.
      workMode: sl<WorkModeService>(),
    ),
  );

  // Bare client for the endpoints that establish or recover a session. Named
  // so it does not collide with the authenticated client above.
  sl.registerLazySingleton<Dio>(
    () => AppNetwork.createBareClient(logger: sl<AppLogger>()),
    instanceName: bareClientName,
  );

  // TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
  // The mock branches below are an AUTH BYPASS (any credentials sign in) and
  // skip phone-ownership proof. `useMocks` is a compile-time constant, so a
  // live build tree-shakes them away.
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? AuthRemoteDataSourceImpl(
            authedClient: sl<Dio>(),
            bareClient: sl<Dio>(instanceName: bareClientName),
            device: sl(),
            getFixProvider: () => sl.isRegistered<LocationFixProvider>()
                ? sl<LocationFixProvider>()
                : null,
          )
        : MockAuthRemoteDataSource(),
  );

  sl.registerLazySingleton<PhoneOwnershipVerifier>(
    () => DataSourceMode.useLiveApi
        ? FirebasePhoneOwnershipVerifier(logger: sl<AppLogger>())
        : const MockPhoneOwnershipVerifier(),
  );
  sl.registerLazySingleton<PhonePasswordChangeRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? PhonePasswordChangeRemoteDataSourceImpl(authedClient: sl<Dio>())
        : const MockPhonePasswordChangeRemoteDataSource(),
  );
  sl.registerLazySingleton<PhoneResetRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? PhoneResetRemoteDataSourceImpl(
            bareClient: sl<Dio>(instanceName: bareClientName),
          )
        : const MockPhoneResetRemoteDataSource(),
  );
}

/// GetIt instance name for the unauthenticated Dio client.
const String bareClientName = 'bareClient';
