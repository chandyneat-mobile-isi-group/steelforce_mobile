import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/features/my_visits/data/models/fraud_flag_model.dart';
import 'package:steelforce/features/my_visits/data/models/location_sample_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';

/// Drift row ↔ model mappers for route telemetry (T1.5 cutover).
///
/// Mappers — not the DAO, not the repository — are the only code that knows
/// about Drift row/companion shapes (ADR-003 point 2, ADR-004 point 2). Kept in
/// the feature's `data/` layer, mirroring `depot_drift_mappers.dart`.
///
/// The Drift data classes carry a `Row` suffix (`@DataClassName`) because the
/// generated names would otherwise collide with the domain entities of the same
/// name — `LocationSample`, `FraudFlag` — which is exactly the boundary these
/// mappers exist to cross.

extension LocationSampleRowMapper on LocationSampleRow {
  LocationSampleModel toModel() => LocationSampleModel(
        id: id,
        routeId: routeId,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracy,
        speedMps: speed,
        headingDegrees: heading,
        altitudeMeters: altitude,
        timestamp: timestamp,
        isMocked: isMocked,
      );
}

extension LocationSampleModelMapper on LocationSampleModel {
  LocationSamplesCompanion toCompanion() => LocationSamplesCompanion.insert(
        id: id,
        routeId: routeId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracyMeters,
        speed: speedMps,
        heading: headingDegrees,
        altitude: altitudeMeters,
        timestamp: timestamp,
        isMocked: Value(isMocked),
        // syncState/dirty are left at their schema defaults (`dirty`): a sample
        // captured on-device has not reached SAP. Only the sync engine may
        // declare otherwise, and only after the server confirms.
      );
}

extension FraudFlagRowMapper on FraudFlagRow {
  FraudFlagModel toModel() => FraudFlagModel(
        id: id,
        routeId: routeId,
        stopId: stopId,
        // A legacy row could hold a type this build no longer knows. Failing
        // closed to `other` keeps the evidence rather than throwing it away —
        // dropping a fraud signal is worse than mislabelling one.
        type: FraudFlagType.values.asNameMap()[type] ??
            FraudFlagType.values.first,
        detail: detail,
        timestamp: timestamp,
        blocked: blocked,
      );
}

extension FraudFlagModelMapper on FraudFlagModel {
  FraudFlagsCompanion toCompanion() => FraudFlagsCompanion.insert(
        id: id,
        routeId: routeId,
        stopId: Value(stopId),
        type: type.name,
        detail: detail,
        timestamp: timestamp,
        blocked: Value(blocked),
      );
}
