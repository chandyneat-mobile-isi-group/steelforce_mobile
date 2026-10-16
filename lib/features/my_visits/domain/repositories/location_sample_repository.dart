import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';

abstract interface class LocationSampleRepository {
  ResultFuture<void> recordSample(LocationSample sample);
  ResultFuture<List<LocationSample>> fetchSamples(String routeId);
  ResultFuture<void> recordFraudFlag(FraudFlag flag);
  ResultFuture<List<FraudFlag>> fetchFraudFlags(String routeId);
}
