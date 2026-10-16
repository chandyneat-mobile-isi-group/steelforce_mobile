import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/fetch_favorites.dart';
import 'package:steelforce/features/order/domain/usecases/get_product_by_id.dart';
import 'package:steelforce/features/order/domain/usecases/get_product_variants.dart';
import 'package:steelforce/features/order/domain/usecases/get_warehouse_stock.dart';
import 'package:steelforce/features/order/domain/usecases/record_viewed.dart';
import 'package:steelforce/features/order/domain/usecases/toggle_favorite.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/product_detail_state.dart';

class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit({
    required GetProductById getProductById,
    required GetProductVariants getProductVariants,
    required GetWarehouseStock getWarehouseStock,
    required ToggleFavorite toggleFavorite,
    required RecordViewed recordViewed,
    required FetchFavorites fetchFavorites,
  })  : _getProductById = getProductById,
        _getProductVariants = getProductVariants,
        _getWarehouseStock = getWarehouseStock,
        _toggleFavorite = toggleFavorite,
        _recordViewed = recordViewed,
        _fetchFavorites = fetchFavorites,
        super(const ProductDetailLoading());

  final GetProductById _getProductById;
  final GetProductVariants _getProductVariants;
  final GetWarehouseStock _getWarehouseStock;
  final ToggleFavorite _toggleFavorite;
  final RecordViewed _recordViewed;
  final FetchFavorites _fetchFavorites;

  Future<void> load(String productId) async {
    emit(const ProductDetailLoading());
    final result = await _getProductById(ProductIdParams(productId));
    await result.when(
      success: (product) async {
        final variantsResult =
            await _getProductVariants(FamilyIdParams(product.familyId));
        final warehouseResult =
            await _getWarehouseStock(ProductCodeParams(product.code));
        final favoritesResult = await _fetchFavorites(const NoParams());
        await _recordViewed(ProductIdParams(product.id));
        emit(ProductDetailLoaded(
          product: product,
          variants:
              variantsResult.when(success: (v) => v, failure: (_) => const []),
          warehouseStock:
              warehouseResult.when(success: (v) => v, failure: (_) => const []),
          isFavorite: favoritesResult.when(
            success: (favs) => favs.any((f) => f.id == product.id),
            failure: (_) => false,
          ),
        ));
      },
      failure: (f) async => emit(ProductDetailError(f.message)),
    );
  }

  Future<void> toggleFavorite() async {
    final current = state;
    if (current is! ProductDetailLoaded) return;
    emit(current.copyWith(isFavorite: !current.isFavorite));
    await _toggleFavorite(ProductIdParams(current.product.id));
  }
}
