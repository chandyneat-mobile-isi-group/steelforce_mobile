import 'package:steelforce/core/utils/enum_parse.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';

class DepotStopInfoModel extends DepotStopInfo {
  const DepotStopInfoModel({
    required super.id,
    required super.name,
    super.nameKh,
    required super.code,
    required super.contact,
    required super.phone,
    required super.address,
    required super.territory,
    required super.territoryType,
    required super.latitude,
    required super.longitude,
    super.geofenceRadiusOverride,
  });

  factory DepotStopInfoModel.fromJson(DataMap json) => DepotStopInfoModel(
        id: json['id'] as String,
        name: json['name'] as String,
        // Absent on payloads generated before the catalog went bilingual;
        // `''` is the documented "no Khmer name" value, not a parse failure.
        nameKh: json['nameKh'] as String? ?? '',
        code: json['code'] as String,
        contact: json['contact'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String,
        territory: json['territory'] as String,
        territoryType: TerritoryType.values.byNameOr(
            json['territoryType'] as String?, TerritoryType.values.first,
            context: 'stop.json.territory'),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        geofenceRadiusOverride:
            (json['geofenceRadiusOverride'] as num?)?.toDouble(),
      );

  factory DepotStopInfoModel.fromRow(DataMap row) => DepotStopInfoModel(
        id: row['id'] as String,
        name: row['name'] as String,
        nameKh: row['name_kh'] as String? ?? '',
        code: row['code'] as String,
        contact: row['contact'] as String,
        phone: row['phone'] as String,
        address: row['address'] as String,
        territory: row['territory'] as String,
        territoryType: TerritoryType.values.byNameOr(
            row['territory_type'] as String?, TerritoryType.values.first,
            context: 'stop.row.territory'),
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        geofenceRadiusOverride:
            (row['geofence_radius_override'] as num?)?.toDouble(),
      );

  DataMap toRow() => {
        'id': id,
        'name': name,
        'name_kh': nameKh,
        'code': code,
        'contact': contact,
        'phone': phone,
        'address': address,
        'territory': territory,
        'territory_type': territoryType.name,
        'latitude': latitude,
        'longitude': longitude,
        'geofence_radius_override': geofenceRadiusOverride,
      };
}
