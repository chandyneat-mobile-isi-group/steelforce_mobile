import 'package:get_it/get_it.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/geo_location/data/datasources/geo_local_data_source.dart';
import 'package:steelforce/features/geo_location/data/datasources/geo_seed_asset_loader.dart';
import 'package:steelforce/features/geo_location/data/repositories/geo_location_repository_impl.dart';
import 'package:steelforce/features/geo_location/domain/repositories/geo_location_repository.dart';
import 'package:steelforce/features/geo_location/domain/usecases/ensure_geo_data_ready.dart';
import 'package:steelforce/features/geo_location/domain/usecases/get_geo_children.dart';
import 'package:steelforce/features/geo_location/domain/usecases/resolve_geo_address.dart';
import 'package:steelforce/features/geo_location/domain/usecases/search_geo_units.dart';

/// Registers the shared geo-location component.
///
/// Everything is a lazy singleton **except the bloc**, which the selector
/// widget constructs per instance — a screen with a billing address and a
/// delivery address needs two independent cascades, and a shared bloc would
/// make changing one clear the other. The repository is shared on purpose,
/// because its level cache is what makes the second selector on a screen open
/// instantly.
///
/// Registered after the database, since [GeoDao] comes off [AppDatabase].
void registerGeoLocationFeature(GetIt sl) {
  sl.registerLazySingleton<GeoSeedAssetLoader>(
      () => const GeoSeedAssetLoader());

  sl.registerLazySingleton<GeoLocalDataSource>(
    () => GeoDriftLocalDataSource(sl<AppDatabase>().geoDao, sl()),
  );

  sl.registerLazySingleton<GeoLocationRepository>(
    () => GeoLocationRepositoryImpl(sl(), sl<AppLogger>()),
  );

  sl.registerLazySingleton<EnsureGeoDataReady>(() => EnsureGeoDataReady(sl()));
  sl.registerLazySingleton<GetGeoChildren>(() => GetGeoChildren(sl()));
  sl.registerLazySingleton<SearchGeoUnits>(() => SearchGeoUnits(sl()));
  sl.registerLazySingleton<ResolveGeoAddress>(() => ResolveGeoAddress(sl()));
}
