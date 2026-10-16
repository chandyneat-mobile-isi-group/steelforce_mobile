import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity_type.dart';

class DepotActivityModel extends DepotActivity {
  const DepotActivityModel({
    required super.id,
    required super.depotId,
    required super.type,
    required super.summary,
    required super.createdAt,
    super.synced,
  });

  factory DepotActivityModel.fromRow(DataMap row) => DepotActivityModel(
        id: row['id'] as String,
        depotId: row['depot_id'] as String,
        type: DepotActivityType.fromValue(row['type'] as String),
        summary: row['summary'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        synced: (row['synced'] as int? ?? 0) == 1,
      );

  DataMap toRow() => {
        'id': id,
        'depot_id': depotId,
        'type': type.value,
        'summary': summary,
        'created_at': createdAt.toIso8601String(),
        'synced': synced ? 1 : 0,
      };
}
