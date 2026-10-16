import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_paged_result.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';

class BrowseDepots extends UseCase<DepotPagedResult, BrowseDepotsParams> {
  const BrowseDepots(this._repository);
  final DepotRepository _repository;

  @override
  ResultFuture<DepotPagedResult> call(BrowseDepotsParams params) =>
      _repository.browse(
        page: params.page,
        pageSize: params.pageSize,
        query: params.query,
        filter: params.filter,
      );
}
