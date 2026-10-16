import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';

class FetchFavoriteDepots extends UseCase<List<Depot>, NoParams> {
  const FetchFavoriteDepots(this._repository);
  final DepotRepository _repository;

  @override
  ResultFuture<List<Depot>> call(NoParams params) =>
      _repository.fetchFavorites();
}
