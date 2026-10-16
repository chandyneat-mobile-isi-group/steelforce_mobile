import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

sealed class CatalogState extends Equatable {
  const CatalogState();
  @override
  List<Object?> get props => [];
}

/// Deferred-fetch landing state: the catalog is open but has made no network
/// round-trip yet. We sit here until the user runs an explicit query (text,
/// voice, image, barcode) or picks a category — keeping catalog entry instant.
final class CatalogIdle extends CatalogState {
  const CatalogIdle();
}

final class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

final class CatalogLoaded extends CatalogState {
  const CatalogLoaded({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.isLoadingMore,
    required this.query,
    required this.filter,
    required this.brands,
  });

  final List<Product> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String query;
  final ProductFilter filter;
  final List<String> brands;

  CatalogLoaded copyWith({
    List<Product>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? query,
    ProductFilter? filter,
    List<String>? brands,
  }) {
    return CatalogLoaded(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      brands: brands ?? this.brands,
    );
  }

  @override
  List<Object?> get props =>
      [items, page, hasMore, isLoadingMore, query, filter, brands];
}

final class CatalogError extends CatalogState {
  const CatalogError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
