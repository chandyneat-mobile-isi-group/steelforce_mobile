import 'package:get_it/get_it.dart';
import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/features/app_coach/data/datasource/coach_local_datasource.dart';
import 'package:steelforce/features/app_coach/data/repositories/coach_repository_impl.dart';
import 'package:steelforce/features/app_coach/domain/repositories/coach_repository.dart';
import 'package:steelforce/features/app_coach/domain/usecases/complete_step.dart';
import 'package:steelforce/features/app_coach/domain/usecases/next_step.dart';
import 'package:steelforce/features/app_coach/domain/usecases/skip_tutorial.dart';
import 'package:steelforce/features/app_coach/domain/usecases/start_tutorial.dart';
import 'package:steelforce/features/app_coach/presentation/blocs/app_coach_bloc.dart';

/// Registers the App Coach feature.
///
/// The bloc is a **lazy singleton** (not a factory): a single coach session is
/// shared across the whole shell and reachable context-free through the
/// `AppCoach` facade.
void registerAppCoachFeature(GetIt sl) {
  // Data
  sl.registerLazySingleton<CoachLocalDataSource>(
    () => CoachLocalDataSourceImpl(HiveService.cacheBox),
  );
  sl.registerLazySingleton<CoachRepository>(
    () => CoachRepositoryImpl(sl()),
  );

  // Domain use cases
  sl.registerLazySingleton(() => StartTutorial(sl()));
  sl.registerLazySingleton(() => CompleteStep(sl()));
  sl.registerLazySingleton(() => SkipTutorial(sl()));
  sl.registerLazySingleton(() => const NextStep());

  // Presentation
  sl.registerLazySingleton<AppCoachBloc>(
    () => AppCoachBloc(
      repository: sl(),
      startTutorial: sl(),
      completeStep: sl(),
      skipTutorial: sl(),
      nextStep: sl(),
    ),
  );
}
