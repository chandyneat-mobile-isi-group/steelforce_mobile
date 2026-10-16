import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/features/geo_location/domain/repositories/geo_location_repository.dart';

class GetGeoChildrenParams extends Equatable {
  const GetGeoChildrenParams({required this.level, this.parentCode});

  final GeoLevel level;

  /// Null only for [GeoLevel.province].
  final String? parentCode;

  @override
  List<Object?> get props => [level, parentCode];
}

/// Loads one level of the cascade: the districts of a province, the communes of
/// a district, the villages of a commune.
///
/// One use case for all four levels rather than four that differ by a single
/// argument. `docs/skills/ai-engineering-playbook.md` forbids a use case that branches
/// on a "mode" to do several unrelated things — this does one thing, and the
/// level is data, not a mode: the caller is a cascade whose whole job is to
/// walk levels uniformly.
class GetGeoChildren extends UseCase<List<GeoUnit>, GetGeoChildrenParams> {
  const GetGeoChildren(this._repository);
  final GeoLocationRepository _repository;

  @override
  ResultFuture<List<GeoUnit>> call(GetGeoChildrenParams params) =>
      _repository.childrenOf(params.level, params.parentCode);
}
