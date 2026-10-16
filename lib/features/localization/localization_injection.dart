import 'package:get_it/get_it.dart';
import 'package:steelforce/core/localization/language_manager.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/localization/data/datasources/language_local_datasource.dart';
import 'package:steelforce/features/localization/data/repositories/language_repository_impl.dart';
import 'package:steelforce/features/localization/domain/repositories/language_repository.dart';
import 'package:steelforce/features/localization/domain/usecases/change_language.dart';
import 'package:steelforce/features/localization/domain/usecases/get_current_language.dart';
import 'package:steelforce/features/localization/domain/usecases/get_supported_languages.dart';
import 'package:steelforce/features/localization/domain/usecases/restore_saved_language.dart';
import 'package:steelforce/features/localization/presentation/bloc/language_cubit.dart';

/// Registers the localization feature. Singleton cubit — there is exactly one
/// app language, and it is provided by value above `MaterialApp` (app.dart) so
/// its synchronous state seed and async bundle restore run once per process.
void registerLocalizationFeature(GetIt sl) {
  sl.registerLazySingleton<LanguageManager>(
    () => LanguageManager(LocalizationService.instance),
  );
  sl.registerLazySingleton<LanguageLocalDatasource>(
    () => LanguageLocalDatasourceImpl(sl()),
  );
  sl.registerLazySingleton<LanguageRepository>(
    () => LanguageRepositoryImpl(datasource: sl(), manager: sl()),
  );
  sl.registerLazySingleton<GetCurrentLanguage>(() => GetCurrentLanguage(sl()));
  sl.registerLazySingleton<GetSupportedLanguages>(
    () => GetSupportedLanguages(sl()),
  );
  sl.registerLazySingleton<ChangeLanguage>(() => ChangeLanguage(sl()));
  sl.registerLazySingleton<RestoreSavedLanguage>(
    () => RestoreSavedLanguage(sl()),
  );
  sl.registerLazySingleton<LanguageCubit>(
    () => LanguageCubit(
      getCurrentLanguage: sl(),
      getSupportedLanguages: sl(),
      changeLanguage: sl(),
      restoreSavedLanguage: sl(),
    ),
  );
}
