import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_note.dart';

class DepotNoteModel extends DepotNote {
  const DepotNoteModel({
    required super.id,
    required super.depotId,
    required super.body,
    required super.createdAt,
    super.synced,
  });

  factory DepotNoteModel.fromRow(DataMap row) => DepotNoteModel(
        id: row['id'] as String,
        depotId: row['depot_id'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        synced: (row['synced'] as int? ?? 0) == 1,
      );

  DataMap toRow() => {
        'id': id,
        'depot_id': depotId,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'synced': synced ? 1 : 0,
      };
}
