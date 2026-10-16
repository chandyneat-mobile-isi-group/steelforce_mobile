import 'package:flutter/widgets.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/fetch_favorites.dart';
import 'package:steelforce/features/order/domain/usecases/toggle_favorite.dart';

/// The rep's favourite products for a screen that shows product cards.
///
/// Call [loadFavorites] from `initState`. A toggle updates the heart at once
/// and then writes; a failed load leaves the set empty rather than blocking
/// the screen.
mixin FavoriteProductsMixin<T extends StatefulWidget> on State<T> {
  Set<String> favoriteIds = {};

  Future<void> loadFavorites() async {
    final result = await sl<FetchFavorites>()(const NoParams());
    if (!mounted) return;
    result.when(
      success: (products) =>
          setState(() => favoriteIds = products.map((p) => p.id).toSet()),
      failure: (_) {},
    );
  }

  Future<void> toggleFavorite(Product product) async {
    setState(() {
      if (!favoriteIds.add(product.id)) favoriteIds.remove(product.id);
    });
    await sl<ToggleFavorite>()(ProductIdParams(product.id));
  }
}
