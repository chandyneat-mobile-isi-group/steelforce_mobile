import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/repositories/geo_location_repository.dart';

class ResolveGeoAddressParams extends Equatable {
  const ResolveGeoAddressParams({
    this.provinceCode,
    this.districtCode,
    this.communeCode,
    this.villageCode,
    this.postalCode,
  });

  final String? provinceCode;
  final String? districtCode;
  final String? communeCode;
  final String? villageCode;

  /// A previously stored code. Kept only if the resolved commune has none of
  /// its own — otherwise the gazetteer wins, because a stored code may predate
  /// a postal reassignment.
  final String? postalCode;

  @override
  List<Object?> get props =>
      [provinceCode, districtCode, communeCode, villageCode, postalCode];
}

/// Rehydrates a saved address from its codes, dropping any level that does not
/// belong to the one above it.
///
/// This is the boundary the §14 integrity rule actually protects. Codes come
/// back from a server draft, a Drift row or a deep link, none of which went
/// through the cascade, so none of which is guaranteed consistent.
class ResolveGeoAddress extends UseCase<GeoAddress, ResolveGeoAddressParams> {
  const ResolveGeoAddress(this._repository);
  final GeoLocationRepository _repository;

  @override
  ResultFuture<GeoAddress> call(ResolveGeoAddressParams params) =>
      _repository.resolveAddress(
        provinceCode: params.provinceCode,
        districtCode: params.districtCode,
        communeCode: params.communeCode,
        villageCode: params.villageCode,
        postalCode: params.postalCode,
      );
}
