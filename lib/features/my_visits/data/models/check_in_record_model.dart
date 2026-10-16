import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';

class CheckInRecordModel extends CheckInRecord {
  const CheckInRecordModel({
    required super.id,
    required super.stopId,
    required super.timestamp,
    required super.latitude,
    required super.longitude,
    required super.accuracyMeters,
    required super.distanceFromDepotMeters,
    required super.isMocked,
    super.overrideReason,
    super.routeId,
  });

  factory CheckInRecordModel.fromRow(DataMap row) => CheckInRecordModel(
        id: row['id'] as String,
        stopId: row['stop_id'] as String,
        timestamp: DateTime.parse(row['timestamp'] as String),
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        accuracyMeters: (row['accuracy'] as num).toDouble(),
        distanceFromDepotMeters: (row['distance_from_depot'] as num).toDouble(),
        isMocked: (row['is_mocked'] as int) == 1,
        overrideReason: row['override_reason'] as String?,
      );

  DataMap toRow() => {
        'id': id,
        'stop_id': stopId,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracyMeters,
        'distance_from_depot': distanceFromDepotMeters,
        'is_mocked': isMocked ? 1 : 0,
        'override_reason': overrideReason,
      };

  factory CheckInRecordModel.fromEntity(CheckInRecord e) => CheckInRecordModel(
        id: e.id,
        stopId: e.stopId,
        timestamp: e.timestamp,
        latitude: e.latitude,
        longitude: e.longitude,
        accuracyMeters: e.accuracyMeters,
        distanceFromDepotMeters: e.distanceFromDepotMeters,
        isMocked: e.isMocked,
        overrideReason: e.overrideReason,
        routeId: e.routeId,
      );
}
