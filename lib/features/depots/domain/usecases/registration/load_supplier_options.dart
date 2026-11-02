import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

/// The active branches or factories a new depot can rank as suppliers.
class LoadSupplierOptions
    extends UseCase<List<SupplierOption>, DepotSupplierType> {
  const LoadSupplierOptions(this._repository);

  final DepotDraftRepository _repository;

  @override
  ResultFuture<List<SupplierOption>> call(DepotSupplierType params) =>
      _repository.loadSupplierOptions(params);
}
