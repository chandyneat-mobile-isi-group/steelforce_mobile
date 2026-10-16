import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';

sealed class DepotsEvent extends Equatable {
  const DepotsEvent();
  @override
  List<Object?> get props => [];
}

final class DepotsLoadRequested extends DepotsEvent {
  const DepotsLoadRequested();
}

final class DepotsRefreshRequested extends DepotsEvent {
  const DepotsRefreshRequested();
}

final class DepotsLoadMoreRequested extends DepotsEvent {
  const DepotsLoadMoreRequested();
}

final class DepotsSearchChanged extends DepotsEvent {
  const DepotsSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

final class DepotsFilterChanged extends DepotsEvent {
  const DepotsFilterChanged(this.filter);
  final DepotFilter filter;
  @override
  List<Object?> get props => [filter];
}

/// Restores the directory's unfiltered first page from the empty state.
final class DepotsFiltersCleared extends DepotsEvent {
  const DepotsFiltersCleared();
}

final class DepotsFavoriteToggled extends DepotsEvent {
  const DepotsFavoriteToggled(this.depotId);
  final String depotId;
  @override
  List<Object?> get props => [depotId];
}
