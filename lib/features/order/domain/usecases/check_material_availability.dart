import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/repositories/material_availability_repository.dart';

class MaterialAvailabilityParams extends Equatable {
  const MaterialAvailabilityParams(this.material);

  /// The SAP material number, not the platform row id.
  final String material;

  @override
  List<Object?> get props => [material];
}

/// The one place the flow asks SAP whether the rep may actually sell what they
/// just picked.
class CheckMaterialAvailability
    extends UseCase<MaterialAvailability, MaterialAvailabilityParams> {
  const CheckMaterialAvailability(this._repository);
  final MaterialAvailabilityRepository _repository;

  @override
  ResultFuture<MaterialAvailability> call(MaterialAvailabilityParams params) =>
      _repository.checkAvailability(params.material);
}
