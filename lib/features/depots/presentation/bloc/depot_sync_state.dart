import 'package:equatable/equatable.dart';

sealed class DepotSyncState extends Equatable {
  const DepotSyncState();
  @override
  List<Object?> get props => [];
}

final class DepotSyncIdle extends DepotSyncState {
  const DepotSyncIdle();
}

final class DepotSyncInProgress extends DepotSyncState {
  const DepotSyncInProgress({required this.isInitial});
  final bool isInitial;
  @override
  List<Object?> get props => [isInitial];
}

final class DepotSyncSucceeded extends DepotSyncState {
  const DepotSyncSucceeded({
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

final class DepotSyncFailed extends DepotSyncState {
  const DepotSyncFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
