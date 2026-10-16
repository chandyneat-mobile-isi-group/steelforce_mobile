import 'package:steelforce/core/utils/enum_parse.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';

class FraudFlagModel extends FraudFlag {
  const FraudFlagModel({
    required super.id,
    required super.routeId,
    required super.type,
    required super.detail,
    required super.timestamp,
    required super.blocked,
    super.stopId,
  });

  factory FraudFlagModel.fromRow(DataMap row) => FraudFlagModel(
        id: row['id'] as String,
        routeId: row['route_id'] as String,
        stopId: row['stop_id'] as String?,
        type: FraudFlagType.values.byNameOr(
            row['type'] as String?, FraudFlagType.values.first,
            context: 'fraud.row.type'),
        detail: row['detail'] as String,
        timestamp: DateTime.parse(row['timestamp'] as String),
        blocked: (row['blocked'] as int) == 1,
      );

  DataMap toRow() => {
        'id': id,
        'route_id': routeId,
        'stop_id': stopId,
        'type': type.name,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
        'blocked': blocked ? 1 : 0,
      };
}
