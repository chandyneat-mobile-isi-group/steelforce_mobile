import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/my_visits/data/local/depot_selection_store.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/depot_selection_state.dart';

/// Drives the Depot/Shop selection screen. Reuses the existing
/// [BrowseDepots] use case (shops == depots) — no new data layer. Search
/// is debounced; the last selection is restored (but not forced) from
/// [DepotSelectionStore].
class DepotSelectionCubit extends Cubit<DepotSelectionState> {
  DepotSelectionCubit({
    required BrowseDepots browseDepots,
    required DepotSelectionStore store,
  })  : _browseDepots = browseDepots,
        _store = store,
        super(const DepotSelectionState());

  final BrowseDepots _browseDepots;
  final DepotSelectionStore _store;
  Timer? _debounce;

  static const _pageSize = 200;

  Future<void> load() async {
    emit(state.copyWith(status: DepotSelectionStatus.loading));
    final result = await _browseDepots(
      BrowseDepotsParams(page: 0, pageSize: _pageSize, query: state.query),
    );
    result.when(
      success: (paged) {
        final shops = paged.items;
        if (shops.isEmpty) {
          emit(state
              .copyWith(status: DepotSelectionStatus.empty, shops: const []));
          return;
        }
        // Restore the last selection only if it's still in the list and the
        // user hasn't already picked one this session (never forced).
        final restored = state.selectedId ??
            (shops.any((s) => s.id == _store.lastShopId)
                ? _store.lastShopId
                : null);
        emit(state.copyWith(
          status: DepotSelectionStatus.loaded,
          shops: shops,
          selectedId: () => restored,
        ));
      },
      failure: (f) => emit(state.copyWith(
          status: DepotSelectionStatus.error, message: f.message)),
    );
  }

  Future<void> refresh() => load();

  void search(String query) {
    emit(state.copyWith(query: query));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), load);
  }

  void select(String shopId) {
    _store.saveLastShopId(shopId);
    emit(state.copyWith(selectedId: () => shopId));
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
