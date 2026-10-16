import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/geo_location/domain/repositories/geo_location_repository.dart';

/// Imports the bundled gazetteer if it is not already in the database.
///
/// Called when the selector mounts rather than at startup. Seeding costs a
/// one-off ~1.3 MB parse and 16,000 inserts, and most sessions never open an
/// address form — paying that on every cold start to save it on the rare
/// launch that needs it is the wrong trade for a handset.
class EnsureGeoDataReady extends UseCase<void, NoParams> {
  const EnsureGeoDataReady(this._repository);
  final GeoLocationRepository _repository;

  @override
  ResultFuture<void> call(NoParams params) => _repository.ensureSeeded();
}
