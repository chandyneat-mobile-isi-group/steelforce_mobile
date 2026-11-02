import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// What one list can be filtered by: only values its depots actually carry,
/// so no choice ever returns an empty list for want of data.
class DepotFilterOptions extends Equatable {
  const DepotFilterOptions({
    this.statuses = const [],
    this.provinces = const [],
    this.channels = const [],
  });

  final List<DepotStatus> statuses;

  /// Regions: the provinces the depots' addresses end with.
  final List<String> provinces;

  /// Types: the depots' distribution channels.
  final List<String> channels;

  @override
  List<Object?> get props => [statuses, provinces, channels];
}
