import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_contact.dart';

class DepotContactModel extends DepotContact {
  const DepotContactModel({
    required super.id,
    required super.name,
    required super.role,
    required super.phone,
    super.email,
  });

  factory DepotContactModel.fromRow(DataMap row) => DepotContactModel(
        id: row['id'] as String,
        name: row['name'] as String,
        role: row['role'] as String,
        phone: row['phone'] as String,
        email: row['email'] as String?,
      );

  DataMap toRow(String depotId) => {
        'id': id,
        'depot_id': depotId,
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
      };
}
