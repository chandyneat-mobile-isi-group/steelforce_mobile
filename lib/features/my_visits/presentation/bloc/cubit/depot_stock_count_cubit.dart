import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/active_language.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_by_id.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_stock_update.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/depot_stock_count_state.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';
import 'package:steelforce/features/order/domain/usecases/browse_products.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/run_initial_sync.dart';

/// Loads the inventory for a selected depot/shop and owns the per-SKU stock
/// statuses (status selection is business state, so it lives here — never
/// `setState`).
///
/// Shop == depot (per the chosen data model): the shop is resolved via
/// [GetDepotById] for display/validation, and the SKUs come from the
/// offline product catalog via [BrowseProducts]. [submit] persists every
/// selection through [AddStockUpdate] — local-first, `sync_state = 'dirty'`,
/// so the depot count pushes with the next visit-data drain without any
/// network dependency.
class DepotStockCountCubit extends Cubit<DepotStockCountState> {
  DepotStockCountCubit({
    required GetDepotById getDepotById,
    required BrowseProducts browseProducts,
    required AddStockUpdate addStockUpdate,
    required RunInitialSync runInitialSync,
    required SessionManager sessionManager,
  })  : _getDepotById = getDepotById,
        _browseProducts = browseProducts,
        _addStockUpdate = addStockUpdate,
        _runInitialSync = runInitialSync,
        _sessionManager = sessionManager,
        super(const DepotStockCountState());

  final GetDepotById _getDepotById;
  final BrowseProducts _browseProducts;
  final AddStockUpdate _addStockUpdate;
  final RunInitialSync _runInitialSync;
  final SessionManager _sessionManager;

  static const _pageSize = 40;

  /// Loads the depot's inventory, **offline-first**:
  ///
  /// 1. Read the local catalog first — instant, no network.
  /// 2. If it's empty (fresh install, wiped DB, or catalog never synced yet),
  ///    pull it once via [RunInitialSync] and re-read locally — so the rep gets
  ///    products instead of a dead end. `RunInitialSync` itself no-ops offline
  ///    (returns a network failure), in which case we show a *meaningful*
  ///    empty state ("connect once to download the catalog") with Retry —
  ///    never a blank screen.
  Future<void> load(String? shopId) async {
    if (shopId == null || shopId.isEmpty) {
      emit(state.copyWith(
        status: DepotStockCountStatus.error,
        message: 'my_visits.depot.none_selected'.tr,
      ));
      return;
    }

    emit(state.copyWith(status: DepotStockCountStatus.loading));

    final depotResult = await _getDepotById(DepotIdParams(shopId));
    // Resolved here rather than in the widget because the name lands in cubit
    // state and is read back by the stock-count header; a cubit has no
    // BuildContext, so [ActiveLanguage] supplies the locale.
    final shopName = depotResult.when(
        success: (c) => ActiveLanguage.resolve(c.displayName),
        failure: (_) => null);
    if (shopName == null) {
      emit(state.copyWith(
        status: DepotStockCountStatus.error,
        message: 'my_visits.depot.load_failed'.tr,
      ));
      return;
    }

    // 1. Local-first read.
    final local = await _browseLocal();
    if (local.error != null) {
      emit(state.copyWith(
        status: DepotStockCountStatus.error,
        shopName: shopName,
        message: local.error,
      ));
      return;
    }

    var lines = local.lines!;

    // 2. Empty catalog → pull once, then re-read.
    if (lines.isEmpty) {
      emit(state.copyWith(
        status: DepotStockCountStatus.syncing,
        shopName: shopName,
      ));
      final synced = await _syncCatalog();
      if (synced) {
        final refetched = await _browseLocal();
        lines = refetched.lines ?? const [];
      }
      if (lines.isEmpty) {
        emit(state.copyWith(
          status: DepotStockCountStatus.empty,
          shopName: shopName,
          // Offline + empty is actionable ("connect to download"); an online
          // pull that still found nothing is a genuine empty catalog.
          message: synced ? null : 'my_visits.depot.catalog_offline'.tr,
        ));
        return;
      }
    }

    emit(state.copyWith(
      status: DepotStockCountStatus.loaded,
      shopName: shopName,
      lines: lines,
    ));
  }

  /// Reads the local catalog page. Returns the mapped lines, or an error
  /// message if the local read itself failed (typed failure from the repo).
  Future<({List<StockCountLine>? lines, String? error})> _browseLocal() async {
    final result = await _browseProducts(
      const BrowseProductsParams(page: 0, pageSize: _pageSize),
    );
    return result.when(
      success: (paged) =>
          (lines: paged.items.map(_lineOf).toList(), error: null),
      failure: (f) => (lines: null, error: f.message),
    );
  }

  /// Pulls the catalog once for the current rep's scope. Returns whether the
  /// pull succeeded; offline/network failures return false (handled by the
  /// caller as an actionable empty state, not an error).
  Future<bool> _syncCatalog() async {
    final result =
        await _runInitialSync(SyncScope.forCurrentUser(_sessionManager));
    return result.when(success: (_) => true, failure: (_) => false);
  }

  /// Sets one SKU's three-tier stock status.
  void selectStockLevel(String productId, StockLevel level) {
    final lines = [
      for (final line in state.lines)
        if (line.productId == productId) line.copyWith(level: level) else line,
    ];
    emit(state.copyWith(lines: lines));
  }

  /// Persists every selected status for [shopId]. Refuses (and turns on row
  /// validation highlighting) while any visible product is still unset.
  Future<void> submit(String shopId) async {
    if (state.status != DepotStockCountStatus.loaded) return;
    if (!state.isComplete) {
      emit(state.copyWith(showValidation: true));
      return;
    }

    emit(state.copyWith(status: DepotStockCountStatus.saving));
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (final line in state.lines) {
      final result = await _addStockUpdate(VisitStockUpdate(
        id: '$stamp-${line.productId.hashCode}',
        depotId: shopId,
        productId: line.productId,
        productName: line.name,
        stockLevel: line.level!,
        notes: '',
      ));
      final failure = result.when(success: (_) => null, failure: (f) => f);
      if (failure != null) {
        emit(state.copyWith(
          status: DepotStockCountStatus.loaded,
          message: failure.message,
        ));
        return;
      }
    }
    emit(state.copyWith(status: DepotStockCountStatus.saved));
  }

  StockCountLine _lineOf(Product p) => StockCountLine(
        productId: p.id,
        name: p.name,
        subtitle: [p.brand, p.sku].where((s) => s.isNotEmpty).join(' · '),
        imageUrl: p.imageUrl,
        size: p.size,
      );
}
