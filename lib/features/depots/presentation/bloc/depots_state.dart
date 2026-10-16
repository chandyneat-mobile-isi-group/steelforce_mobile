import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';

sealed class DepotsState extends Equatable {
  const DepotsState();
  @override
  List<Object?> get props => [];
}

final class DepotsInitial extends DepotsState {
  const DepotsInitial();
}

final class DepotsLoading extends DepotsState {
  const DepotsLoading();
}

final class DepotsLoaded extends DepotsState {
  const DepotsLoaded({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.isLoadingMore,
    required this.query,
    required this.filter,
    required this.recent,
    required this.favoriteIds,
  });

  final List<Depot> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String query;
  final DepotFilter filter;
  final List<Depot> recent;
  final Set<String> favoriteIds;

  DepotsLoaded copyWith({
    List<Depot>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? query,
    DepotFilter? filter,
    List<Depot>? recent,
    Set<String>? favoriteIds,
  }) {
    return DepotsLoaded(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      recent: recent ?? this.recent,
      favoriteIds: favoriteIds ?? this.favoriteIds,
    );
  }

  @override
  List<Object?> get props =>
      [items, page, hasMore, isLoadingMore, query, filter, recent, favoriteIds];
}

final class DepotsError extends DepotsState {
  const DepotsError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
