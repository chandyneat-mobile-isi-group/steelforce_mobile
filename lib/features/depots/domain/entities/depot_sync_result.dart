import 'package:equatable/equatable.dart';

class DepotSyncResult extends Equatable {
  const DepotSyncResult({
    required this.upserted,
    required this.deleted,
    required this.syncedAt,
  });

  final int upserted;
  final int deleted;
  final DateTime syncedAt;

  @override
  List<Object?> get props => [upserted, deleted, syncedAt];
}
