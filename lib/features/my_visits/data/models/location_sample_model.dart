import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';

class LocationSampleModel extends LocationSample {
  const LocationSampleModel({
    required super.id,
    required super.routeId,
    required super.latitude,
    required super.longitude,
    required super.accuracyMeters,
    required super.speedMps,
    required super.headingDegrees,
    required super.altitudeMeters,
    required super.timestamp,
    required super.isMocked,
  });

  factory LocationSampleModel.fromRow(DataMap row) => LocationSampleModel(
        id: row['id'] as String,
        routeId: row['route_id'] as String,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        accuracyMeters: (row['accuracy'] as num).toDouble(),
        speedMps: (row['speed'] as num).toDouble(),
        headingDegrees: (row['heading'] as num).toDouble(),
        altitudeMeters: (row['altitude'] as num).toDouble(),
        timestamp: DateTime.parse(row['timestamp'] as String),
        isMocked: (row['is_mocked'] as int) == 1,
      );

  DataMap toRow() => {
        'id': id,
        'route_id': routeId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracyMeters,
        'speed': speedMps,
        'heading': headingDegrees,
        'altitude': altitudeMeters,
        'timestamp': timestamp.toIso8601String(),
        'is_mocked': isMocked ? 1 : 0,
      };

  factory LocationSampleModel.fromEntity(LocationSample e) =>
      LocationSampleModel(
        id: e.id,
        routeId: e.routeId,
        latitude: e.latitude,
        longitude: e.longitude,
        accuracyMeters: e.accuracyMeters,
        speedMps: e.speedMps,
        headingDegrees: e.headingDegrees,
        altitudeMeters: e.altitudeMeters,
        timestamp: e.timestamp,
        isMocked: e.isMocked,
      );
}
