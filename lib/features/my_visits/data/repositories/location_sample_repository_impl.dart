import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/fraud_flag_model.dart';
import 'package:steelforce/features/my_visits/data/models/location_sample_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/repositories/location_sample_repository.dart';

class LocationSampleRepositoryImpl implements LocationSampleRepository {
  const LocationSampleRepositoryImpl(this._local);
  final LocationSampleLocalDataSource _local;

  @override
  ResultFuture<void> recordSample(LocationSample sample) async {
    try {
      await _local.insertSample(LocationSampleModel.fromEntity(sample));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<LocationSample>> fetchSamples(String routeId) async {
    try {
      return Success(await _local.fetchSamples(routeId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> recordFraudFlag(FraudFlag flag) async {
    try {
      await _local.insertFraudFlag(FraudFlagModel(
        id: flag.id,
        routeId: flag.routeId,
        stopId: flag.stopId,
        type: flag.type,
        detail: flag.detail,
        timestamp: flag.timestamp,
        blocked: flag.blocked,
      ));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<FraudFlag>> fetchFraudFlags(String routeId) async {
    try {
      return Success(await _local.fetchFraudFlags(routeId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }
}
