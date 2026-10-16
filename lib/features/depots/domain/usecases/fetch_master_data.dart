import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';
import 'package:steelforce/features/depots/domain/repositories/master_data_repository.dart';

/// Reads one SAP master-data list, cache-first.
class FetchMasterData {
  const FetchMasterData(this._repository);
  final MasterDataRepository _repository;

  Future<MasterDataResult> call(MasterDataType type) => _repository.fetch(type);
}
