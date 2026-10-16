import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';

sealed class ProductDetailState extends Equatable {
  const ProductDetailState();
  @override
  List<Object?> get props => [];
}

final class ProductDetailLoading extends ProductDetailState {
  const ProductDetailLoading();
}

final class ProductDetailLoaded extends ProductDetailState {
  const ProductDetailLoaded({
    required this.product,
    required this.variants,
    required this.warehouseStock,
    required this.isFavorite,
  });

  final Product product;
  final List<Product> variants;
  final List<Product> warehouseStock;
  final bool isFavorite;

  ProductDetailLoaded copyWith({Product? product, bool? isFavorite}) =>
      ProductDetailLoaded(
        product: product ?? this.product,
        variants: variants,
        warehouseStock: warehouseStock,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  @override
  List<Object?> get props => [product, variants, warehouseStock, isFavorite];
}

final class ProductDetailError extends ProductDetailState {
  const ProductDetailError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
