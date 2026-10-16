import 'package:steelforce/core/database/drift/daos/route_telemetry_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/telemetry_drift_mappers.dart';
import 'package:steelforce/features/my_visits/data/models/fraud_flag_model.dart';
import 'package:steelforce/features/my_visits/data/models/location_sample_model.dart';

/// [LocationSampleLocalDataSource] backed by the single encrypted Drift database
/// (T1.5 cutover). Replaces the plaintext `routes.db` implementation.
///
/// The interface is unchanged, so nothing above this line moves: the repository,
/// usecases and blocs are untouched by the storage swap — that is the whole
/// point of the repository seam (ADR-003, `docs/blueprint/system-architecture.md` §5: "feature
/// code above the datasource boundary should not need to change").
///
/// Exceptions are normalised to [CacheException] exactly as the legacy
/// implementation did, so the repository's failure mapping is unaffected.
class LocationSampleDriftLocalDataSource
    implements LocationSampleLocalDataSource {
  const LocationSampleDriftLocalDataSource(this._dao);

  final RouteTelemetryDao _dao;

  @override
  Future<void> insertSample(LocationSampleModel sample) async {
    try {
      await _dao.insertSample(sample.toCompanion());
    } catch (e) {
      // §10: the exception type only — a GPS fix is location PII.
      throw CacheException(message: 'Failed to store location sample: $e');
    }
  }

  @override
  Future<List<LocationSampleModel>> fetchSamples(String routeId) async {
    try {
      final rows = await _dao.fetchSamples(routeId);
      return rows.map((r) => r.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load location samples: $e');
    }
  }

  @override
  Future<void> insertFraudFlag(FraudFlagModel flag) async {
    try {
      await _dao.insertFraudFlag(flag.toCompanion());
    } catch (e) {
      throw CacheException(message: 'Failed to store fraud flag: $e');
    }
  }

  @override
  Future<List<FraudFlagModel>> fetchFraudFlags(String routeId) async {
    try {
      final rows = await _dao.fetchFraudFlags(routeId);
      return rows.map((r) => r.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load fraud flags: $e');
    }
  }
}
