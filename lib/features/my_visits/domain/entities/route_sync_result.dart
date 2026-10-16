import 'package:equatable/equatable.dart';

class RouteSyncResult extends Equatable {
  const RouteSyncResult(
      {required this.upserted, required this.deleted, required this.syncedAt});

  final int upserted;
  final int deleted;
  final DateTime syncedAt;

  @override
  List<Object?> get props => [upserted, deleted, syncedAt];
}
