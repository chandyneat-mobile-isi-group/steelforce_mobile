import 'package:equatable/equatable.dart';

sealed class RouteSyncState extends Equatable {
  const RouteSyncState();
  @override
  List<Object?> get props => [];
}

final class RouteSyncIdle extends RouteSyncState {
  const RouteSyncIdle();
}

final class RouteSyncInProgress extends RouteSyncState {
  const RouteSyncInProgress({required this.isInitial});
  final bool isInitial;
  @override
  List<Object?> get props => [isInitial];
}

final class RouteSyncSucceeded extends RouteSyncState {
  const RouteSyncSucceeded({required this.upserted, required this.syncedAt});
  final int upserted;
  final DateTime syncedAt;
  @override
  List<Object?> get props => [upserted, syncedAt];
}

final class RouteSyncFailed extends RouteSyncState {
  const RouteSyncFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
