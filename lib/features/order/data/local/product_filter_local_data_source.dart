import 'package:steelforce/core/database/drift/daos/catalog_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/features/order/data/local/product_drift_mappers.dart';
import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Resolves the *values* of the guided filter flow from the locally synced
/// catalog.
///
/// Splitting values (local) from hierarchy (remote) is what makes the flow
/// offline-first: the schema is configuration a rep can carry, and every option
/// list is a small aggregate over data already on the device. No screen in this
/// flow ever blocks on connectivity.
abstract interface class ProductFilterLocalDataSource {
  Future<List<CategoryModel>> categoriesWithProducts();

  Future<List<CatalogFacetValue>> facetValues({
    required String facet,
    required ProductFilter filter,
  });
}

class ProductFilterDriftLocalDataSource
    implements ProductFilterLocalDataSource {
  const ProductFilterDriftLocalDataSource(this._dao);

  final CatalogDao _dao;

  @override
  Future<List<CategoryModel>> categoriesWithProducts() async {
    try {
      final rows = await _dao.categoriesWithProducts();
      return rows.map((c) => c.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load filter categories: $e');
    }
  }

  @override
  Future<List<CatalogFacetValue>> facetValues({
    required String facet,
    required ProductFilter filter,
  }) async {
    try {
      // pageSize is irrelevant to an aggregate — the DAO only reads the WHERE
      // clause out of the query object.
      return await _dao.distinctFacetValues(
        facet: facet,
        q: filter.toQuery(query: '', page: 0, pageSize: 0),
      );
    } catch (e) {
      throw CacheException(message: 'Failed to load filter options: $e');
    }
  }
}
