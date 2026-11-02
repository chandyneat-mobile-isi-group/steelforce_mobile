import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/profile/data/datasources/auth_backed_profile_data_source.dart';
import 'package:steelforce/features/profile/data/datasources/mock_profile_remote_data_source.dart';
import 'package:steelforce/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:steelforce/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:steelforce/features/profile/domain/repositories/profile_repository.dart';
import 'package:steelforce/features/profile/domain/usecases/change_password.dart';
import 'package:steelforce/features/profile/domain/usecases/get_worker_profile.dart';
import 'package:steelforce/features/profile/domain/usecases/logout_worker.dart';
import 'package:steelforce/features/profile/domain/usecases/update_worker_profile.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';

/// Registers the profile feature: worker profile read/update, password
/// change, and logout. Mirrors `registerMyVisitsFeature`.
void registerProfileFeature(GetIt sl) {
  // ── Data sources ────────────────────────────────────────────────────
  // Backed by the auth layer rather than a profile service of its own: the
  // signed-in employee is `GET /auth/me`, and a second fetch path would be a
  // second answer to "who is signed in". The mock served the same hardcoded
  // "Alex Morgan" to every user.
  //
  // TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? AuthBackedProfileDataSource(
            remote: sl<AuthRemoteDataSource>(),
            local: sl<AuthLocalDataSource>(),
            client: sl<Dio>(),
            session: sl<SessionManager>(),
            apiBaseUrl: AppConfig.apiBaseUrl,
            logger: sl<AppLogger>(),
          )
        : MockProfileRemoteDataSource(auth: sl<AuthRemoteDataSource>()),
  );

  // ── Repositories ────────────────────────────────────────────────────
  sl.registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(remoteDataSource: sl()));

  // ── Use cases ───────────────────────────────────────────────────────
  sl.registerLazySingleton(() => GetWorkerProfile(sl()));
  sl.registerLazySingleton(() => UpdateWorkerProfile(sl()));
  sl.registerLazySingleton(() => ChangePassword(sl()));
  sl.registerLazySingleton(() => LogoutWorker(sl()));

  // ── Presentation ────────────────────────────────────────────────────
  sl.registerFactory(() => ProfileCubit(
        getWorkerProfile: sl(),
        updateWorkerProfile: sl(),
        changePassword: sl(),
        logoutWorker: sl(),
        unsentWork: sl<UnsentWorkService>(),
      ));
}
