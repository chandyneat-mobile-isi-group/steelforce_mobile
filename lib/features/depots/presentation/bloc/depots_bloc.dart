import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_recent_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/toggle_favorite_depot.dart';
import 'package:steelforce/features/depots/presentation/bloc/depots_event.dart';
import 'package:steelforce/features/depots/presentation/bloc/depots_state.dart';

const _pageSize = 30;

/// Paginated depot directory — never loads the whole book into memory,
/// only the visible pages. Search is debounced + `restartable()` so fast
/// typing never races two in-flight queries (same shape as `CatalogBloc`).
class DepotsBloc extends Bloc<DepotsEvent, DepotsState> {
  DepotsBloc({
    required BrowseDepots browseDepots,
    required FetchRecentDepots fetchRecentDepots,
    required ToggleFavoriteDepot toggleFavoriteDepot,
  })  : _browseDepots = browseDepots,
        _fetchRecentDepots = fetchRecentDepots,
        _toggleFavoriteDepot = toggleFavoriteDepot,
        super(const DepotsInitial()) {
    on<DepotsLoadRequested>(_onLoad, transformer: droppable());
    on<DepotsRefreshRequested>(_onRefresh, transformer: droppable());
    on<DepotsLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<DepotsSearchChanged>(_onSearchChanged, transformer: restartable());
    on<DepotsFilterChanged>(_onFilterChanged, transformer: restartable());
    on<DepotsFiltersCleared>(_onFiltersCleared, transformer: restartable());
    on<DepotsFavoriteToggled>(_onFavoriteToggled, transformer: sequential());
  }

  final BrowseDepots _browseDepots;
  final FetchRecentDepots _fetchRecentDepots;
  final ToggleFavoriteDepot _toggleFavoriteDepot;

  Future<void> _onLoad(
      DepotsLoadRequested event, Emitter<DepotsState> emit) async {
    emit(const DepotsLoading());

    final recentResult = await _fetchRecentDepots(const NoParams());
    final recent =
        recentResult.when(success: (r) => r, failure: (_) => const <Depot>[]);

    final result = await _browseDepots(
        const BrowseDepotsParams(page: 0, pageSize: _pageSize));
    result.when(
      success: (paged) => emit(DepotsLoaded(
        items: paged.items,
        page: 0,
        hasMore: paged.hasMore,
        isLoadingMore: false,
        query: '',
        filter: const DepotFilter(),
        recent: recent,
        favoriteIds: const {},
      )),
      failure: (f) => emit(DepotsError(f.message)),
    );
  }

  Future<void> _onRefresh(
      DepotsRefreshRequested event, Emitter<DepotsState> emit) async {
    final current = state;
    if (current is! DepotsLoaded) {
      return _onLoad(const DepotsLoadRequested(), emit);
    }

    final result = await _browseDepots(
      BrowseDepotsParams(
          page: 0,
          pageSize: _pageSize,
          query: current.query,
          filter: current.filter),
    );
    result.when(
      success: (paged) => emit(current.copyWith(
          items: paged.items, page: 0, hasMore: paged.hasMore)),
      failure: (_) => null,
    );
  }

  Future<void> _onLoadMore(
      DepotsLoadMoreRequested event, Emitter<DepotsState> emit) async {
    final current = state;
    if (current is! DepotsLoaded || !current.hasMore || current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    final nextPage = current.page + 1;
    final result = await _browseDepots(
      BrowseDepotsParams(
          page: nextPage,
          pageSize: _pageSize,
          query: current.query,
          filter: current.filter),
    );
    result.when(
      success: (paged) => emit(current.copyWith(
        items: [...current.items, ...paged.items],
        page: nextPage,
        hasMore: paged.hasMore,
        isLoadingMore: false,
      )),
      failure: (_) => emit(current.copyWith(isLoadingMore: false)),
    );
  }

  Future<void> _onSearchChanged(
      DepotsSearchChanged event, Emitter<DepotsState> emit) async {
    final current = state;
    if (current is! DepotsLoaded) return;

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final result = await _browseDepots(
      BrowseDepotsParams(
          page: 0,
          pageSize: _pageSize,
          query: event.query,
          filter: current.filter),
    );
    result.when(
      success: (paged) => emit(current.copyWith(
        items: paged.items,
        page: 0,
        hasMore: paged.hasMore,
        query: event.query,
      )),
      failure: (f) => emit(DepotsError(f.message)),
    );
  }

  Future<void> _onFilterChanged(
      DepotsFilterChanged event, Emitter<DepotsState> emit) async {
    final current = state;
    if (current is! DepotsLoaded) return;

    final result = await _browseDepots(
      BrowseDepotsParams(
          page: 0,
          pageSize: _pageSize,
          query: current.query,
          filter: event.filter),
    );
    result.when(
      success: (paged) => emit(current.copyWith(
        items: paged.items,
        page: 0,
        hasMore: paged.hasMore,
        filter: event.filter,
      )),
      failure: (f) => emit(DepotsError(f.message)),
    );
  }

  Future<void> _onFiltersCleared(
      DepotsFiltersCleared event, Emitter<DepotsState> emit) async {
    final current = state;
    if (current is! DepotsLoaded) return;

    final result = await _browseDepots(
      const BrowseDepotsParams(page: 0, pageSize: _pageSize),
    );
    result.when(
      success: (paged) => emit(current.copyWith(
        items: paged.items,
        page: 0,
        hasMore: paged.hasMore,
        query: '',
        filter: const DepotFilter(),
      )),
      failure: (f) => emit(DepotsError(f.message)),
    );
  }

  Future<void> _onFavoriteToggled(
      DepotsFavoriteToggled event, Emitter<DepotsState> emit) async {
    final current = state;
    if (current is! DepotsLoaded) return;

    final favorites = Set<String>.from(current.favoriteIds);
    if (!favorites.add(event.depotId)) favorites.remove(event.depotId);
    emit(current.copyWith(favoriteIds: favorites));

    await _toggleFavoriteDepot(DepotIdParams(event.depotId));
  }
}
