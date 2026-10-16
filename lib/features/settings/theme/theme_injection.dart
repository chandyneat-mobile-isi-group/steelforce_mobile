import 'package:get_it/get_it.dart';
import 'package:steelforce/core/database/hive/app_preferences.dart';
import 'package:steelforce/features/settings/theme/data/repositories/theme_repository_impl.dart';
import 'package:steelforce/features/settings/theme/domain/repositories/theme_repository.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_cubit.dart';

/// Registers the theme feature. Both the repository and the cubit are
/// singletons: there is exactly one theme for the whole app, and the cubit is
/// provided by value above `MaterialApp` (see `app.dart`) so its synchronous
/// startup restore has already run before the first frame.
void registerThemeFeature(GetIt sl) {
  sl.registerLazySingleton<ThemeRepository>(
    () => ThemeRepositoryImpl(sl<AppPreferences>()),
  );
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit(sl()));
}
