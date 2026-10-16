import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/repositories/location_sample_repository.dart';

class RecordLocationSample extends UseCase<void, LocationSample> {
  const RecordLocationSample(this._repository);
  final LocationSampleRepository _repository;
  @override
  ResultFuture<void> call(LocationSample params) =>
      _repository.recordSample(params);
}
