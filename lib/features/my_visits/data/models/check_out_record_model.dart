import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';

class CheckOutRecordModel extends CheckOutRecord {
  const CheckOutRecordModel({
    required super.id,
    required super.stopId,
    required super.timestamp,
    required super.latitude,
    required super.longitude,
    required super.durationMinutes,
    required super.visitSummary,
    super.checkInId,
    super.outcome,
    super.orders,
    super.noOrderReason,
    super.noOrderNote,
  });

  factory CheckOutRecordModel.fromRow(DataMap row) => CheckOutRecordModel(
        id: row['id'] as String,
        stopId: row['stop_id'] as String,
        timestamp: DateTime.parse(row['timestamp'] as String),
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        durationMinutes: (row['duration_minutes'] as num).toInt(),
        visitSummary: row['visit_summary'] as String,
      );

  DataMap toRow() => {
        'id': id,
        'stop_id': stopId,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'duration_minutes': durationMinutes,
        'visit_summary': visitSummary,
      };

  factory CheckOutRecordModel.fromEntity(CheckOutRecord e) =>
      CheckOutRecordModel(
        id: e.id,
        stopId: e.stopId,
        timestamp: e.timestamp,
        latitude: e.latitude,
        longitude: e.longitude,
        durationMinutes: e.durationMinutes,
        visitSummary: e.visitSummary,
        checkInId: e.checkInId,
        outcome: e.outcome,
        orders: e.orders,
        noOrderReason: e.noOrderReason,
        noOrderNote: e.noOrderNote,
      );
}
