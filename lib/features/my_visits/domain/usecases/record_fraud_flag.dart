import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/repositories/location_sample_repository.dart';

class RecordFraudFlag extends UseCase<void, FraudFlag> {
  const RecordFraudFlag(this._repository);
  final LocationSampleRepository _repository;
  @override
  ResultFuture<void> call(FraudFlag params) =>
      _repository.recordFraudFlag(params);
}
