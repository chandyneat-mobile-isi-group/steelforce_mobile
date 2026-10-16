import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/features/geo_location/domain/repositories/geo_location_repository.dart';

class SearchGeoUnitsParams extends Equatable {
  const SearchGeoUnitsParams({
    required this.level,
    required this.query,
    this.parentCode,
  });

  final GeoLevel level;
  final String query;
  final String? parentCode;

  @override
  List<Object?> get props => [level, query, parentCode];
}

/// Narrows one level's list by a text query, in either language, by code, or by
/// postal code (§7).
class SearchGeoUnits extends UseCase<List<GeoUnit>, SearchGeoUnitsParams> {
  const SearchGeoUnits(this._repository);
  final GeoLocationRepository _repository;

  @override
  ResultFuture<List<GeoUnit>> call(SearchGeoUnitsParams params) =>
      _repository.search(params.level, params.parentCode, params.query);
}
