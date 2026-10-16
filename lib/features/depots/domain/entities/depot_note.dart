import 'package:equatable/equatable.dart';

/// Rep-owned, offline-first. Never touched by sync from SAP.
class DepotNote extends Equatable {
  const DepotNote({
    required this.id,
    required this.depotId,
    required this.body,
    required this.createdAt,
    this.synced = false,
  });

  final String id;
  final String depotId;
  final String body;
  final DateTime createdAt;
  final bool synced;

  @override
  List<Object?> get props => [id, depotId, body, createdAt, synced];
}
