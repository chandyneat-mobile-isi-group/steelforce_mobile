import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/data/remote/api_depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_draft_repository_impl.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

/// New-depot registration against `/api/v1/depot-drafts`: the data source and
/// the repository. Its use cases are registered with the others in
/// `registerDepotUseCases`, so a practice scope rebuilds them over
/// `PracticeDepotDraftRepository` and a lesson never reaches the API.
void registerDepotDraftFeature(GetIt sl) {
  sl.registerLazySingleton<DepotDraftRemoteDataSource>(
    () => ApiDepotDraftRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<DepotDraftRepository>(
    () => DepotDraftRepositoryImpl(
      remote: sl<DepotDraftRemoteDataSource>(),
      network: sl<NetworkInfo>(),
    ),
  );
}
