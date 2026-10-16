import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/usecases/browse_products.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/fetch_brands.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/catalog_event.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/catalog_state.dart';

const _pageSize = 30;

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc(
      {required BrowseProducts browseProducts,
      required FetchBrands fetchBrands})
      : _browseProducts = browseProducts,
        _fetchBrands = fetchBrands,
        super(const CatalogIdle()) {
    on<CatalogLoadRequested>(_onLoad, transformer: droppable());
    on<CatalogRefreshRequested>(_onRefresh, transformer: droppable());
    on<CatalogLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<CatalogSearchChanged>(_onSearchChanged, transformer: restartable());
    on<CatalogFilterChanged>(_onFilterChanged, transformer: restartable());
    on<CatalogRestoreRequested>(_onRestore, transformer: droppable());
    on<CatalogVoiceSearchRequested>(_onVoiceSearch, transformer: restartable());
    on<CatalogImageSearchRequested>(_onImageSearch, transformer: restartable());
  }

  final BrowseProducts _browseProducts;
  final FetchBrands _fetchBrands;

  List<String>? _brands;

  Future<List<String>> _ensureBrands() async {
    if (_brands != null) return _brands!;
    final result = await _fetchBrands(const NoParams());
    return _brands =
        result.when(success: (b) => b, failure: (_) => const <String>[])!;
  }

  Future<void> _runQuery(
      String query, ProductFilter filter, Emitter<CatalogState> emit) async {
    if (state is! CatalogLoaded) emit(const CatalogLoading());
    final brands = await _ensureBrands();
    final result = await _browseProducts(
      BrowseProductsParams(
          page: 0, pageSize: _pageSize, query: query, filter: filter),
    );
    result.when(
      success: (paged) => emit(CatalogLoaded(
        items: paged.items,
        page: 0,
        hasMore: paged.hasMore,
        isLoadingMore: false,
        query: query,
        filter: filter,
        brands: brands,
      )),
      failure: (f) => emit(CatalogError(f.message)),
    );
  }

  Future<void> _onLoad(
          CatalogLoadRequested event, Emitter<CatalogState> emit) =>
      _runQuery('', const ProductFilter(), emit);

  Future<void> _onRestore(
          CatalogRestoreRequested event, Emitter<CatalogState> emit) =>
      _runQuery(event.query, event.filter, emit);

  Future<void> _onSearchChanged(
      CatalogSearchChanged event, Emitter<CatalogState> emit) async {
    final current = state;
    final filter =
        current is CatalogLoaded ? current.filter : const ProductFilter();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _runQuery(event.query, filter, emit);
  }

  Future<void> _onFilterChanged(
      CatalogFilterChanged event, Emitter<CatalogState> emit) async {
    final current = state;
    if (current is CatalogLoaded) {
      // Instantly emit the updated filter state so dropdowns update responsively
      // in the UI without waiting for the network response to finish.
      emit(current.copyWith(filter: event.filter));
    }
    final query = current is CatalogLoaded ? current.query : '';
    await _runQuery(query, event.filter, emit);
  }

  Future<void> _onVoiceSearch(
      CatalogVoiceSearchRequested event, Emitter<CatalogState> emit) async {
    final current = state;
    final filter =
        current is CatalogLoaded ? current.filter : const ProductFilter();
    await _runQuery(event.query, filter, emit);
  }

  Future<void> _onImageSearch(
      CatalogImageSearchRequested event, Emitter<CatalogState> emit) async {
    final current = state;
    final filter =
        current is CatalogLoaded ? current.filter : const ProductFilter();
    await _runQuery(event.query, filter, emit);
  }

  Future<void> _onRefresh(
      CatalogRefreshRequested event, Emitter<CatalogState> emit) async {
    final current = state;
    if (current is! CatalogLoaded) {
      return _runQuery('', const ProductFilter(), emit);
    }

    final result = await _browseProducts(
      BrowseProductsParams(
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
      CatalogLoadMoreRequested event, Emitter<CatalogState> emit) async {
    final current = state;
    if (current is! CatalogLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    final nextPage = current.page + 1;
    final result = await _browseProducts(
      BrowseProductsParams(
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
}
