import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/data/remote/api_depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_backend.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_draft_repository_impl.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

/// New-depot registration against `/api/v1/depot-drafts`: the data source and
/// the repository. Its use cases are registered with the others in
/// `registerDepotUseCases`, so a practice scope rebuilds them over
/// `PracticeDepotDraftRepository` and a lesson never reaches the API.
void registerDepotDraftFeature(GetIt sl) {
  // `MockDepotBackend` is registered by `registerDepotFeature` in a demo build.
  // TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
  sl.registerLazySingleton<DepotDraftRemoteDataSource>(
    () => DataSourceMode.useLiveApi
        ? ApiDepotDraftRemoteDataSource(sl<Dio>())
        : MockDepotDraftRemoteDataSource(sl<MockDepotBackend>()),
  );
  sl.registerLazySingleton<DepotDraftRepository>(
    () => DepotDraftRepositoryImpl(
      remote: sl<DepotDraftRemoteDataSource>(),
      network: sl<NetworkInfo>(),
    ),
  );
}
