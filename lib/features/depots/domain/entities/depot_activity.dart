import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity_type.dart';

/// A single entry on a depot's timeline — merges rep-logged activity
/// (calls, visits, notes) with system-generated events (opportunity
/// created, order placed) into one chronological feed.
class DepotActivity extends Equatable {
  const DepotActivity({
    required this.id,
    required this.depotId,
    required this.type,
    required this.summary,
    required this.createdAt,
    this.synced = false,
  });

  final String id;
  final String depotId;
  final DepotActivityType type;
  final String summary;
  final DateTime createdAt;
  final bool synced;

  @override
  List<Object?> get props => [id, depotId, type, summary, createdAt, synced];
}
