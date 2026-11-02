import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/filter/category_filter_schema.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/entities/filter/product_attribute.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/repositories/product_filter_repository.dart';
import 'package:steelforce/features/order/practice/order_practice_data.dart';

/// A five-item material finder for order lessons, shared by remote and visit
/// practice. It keeps the training path usable without the material selection
/// API and returns to the real source after the practice session closes.
class PracticeProductFilterRepository implements ProductFilterRepository {
  PracticeProductFilterRepository({
    required ProductFilterRepository real,
    required PracticeWorld world,
  })  : _real = real,
        _world = world;

  final ProductFilterRepository _real;
  final PracticeWorld _world;

  static const _categoryCode = OrderPracticeData.practiceMaterialCategoryCode;
  static const _stepKey = OrderPracticeData.practiceMaterialStepKey;

  static const _schema = CategoryFilterSchema(
    categoryId: _categoryCode,
    categoryName: 'Practice steel materials',
    steps: [
      FilterStep(
        key: _stepKey,
        label: 'Choose a sample material',
        attribute: ProductAttribute.sku,
        sortOrder: 1,
        style: FilterStepStyle.list,
        role: FilterStepRole.sku,
      ),
    ],
  );

  bool get _active => !_world.isClosed;

  @override
  ResultFuture<List<MaterialCategory>> getFilterCategories() async {
    if (!_active) return _real.getFilterCategories();
    return Success<List<MaterialCategory>>([
      MaterialCategory(
        code: _categoryCode,
        name: const LocalizedText(
          en: 'Practice materials',
          km: 'សម្ភារៈសម្រាប់ហ្វឹកហាត់',
        ),
        materialCount: OrderPracticeData.practiceMaterials.length,
        hasPublishedSchema: true,
        icon: 'steel',
      ),
    ]);
  }

  @override
  ResultFuture<CategoryFilterSchema> getFilterSchema(
      String categoryCode) async {
    if (!_active) return _real.getFilterSchema(categoryCode);
    if (categoryCode == _categoryCode) return const Success(_schema);
    return _real.getFilterSchema(categoryCode);
  }

  @override
  ResultFuture<List<FilterOption>> getStepOptions({
    required CategoryFilterSchema schema,
    required FilterStep step,
    required FilterSelection selection,
  }) async {
    if (!_active) {
      return _real.getStepOptions(
        schema: schema,
        step: step,
        selection: selection,
      );
    }
    if (schema.categoryId != _categoryCode || step.key != _stepKey) {
      return _real.getStepOptions(
        schema: schema,
        step: step,
        selection: selection,
      );
    }
    return Success<List<FilterOption>>([
      for (final product in OrderPracticeData.practiceMaterials)
        FilterOption(
          value: product.materialNumber,
          label:
              '${product.displayName.resolve('en')} · ${product.materialNumber}',
          matchCount: 1,
        ),
    ]);
  }

  @override
  ResultFuture<List<FilterOption>> getStockLocationOptions({
    required String? categoryId,
    required FilterSelection selection,
  }) async {
    if (!_active) {
      return _real.getStockLocationOptions(
        categoryId: categoryId,
        selection: selection,
      );
    }
    if (categoryId == _categoryCode) {
      return const Success<List<FilterOption>>([]);
    }
    return _real.getStockLocationOptions(
      categoryId: categoryId,
      selection: selection,
    );
  }

  @override
  ResultFuture<PagedResult<Product>> getMaterials({
    required String? categoryCode,
    required FilterSelection selection,
    required int page,
    required int pageSize,
    String search = '',
    ProductSortBy sortBy = ProductSortBy.relevance,
    bool availableOnly = false,
    String? warehouseCode,
  }) async {
    if (!_active) {
      return _real.getMaterials(
        categoryCode: categoryCode,
        selection: selection,
        page: page,
        pageSize: pageSize,
        search: search,
        sortBy: sortBy,
        availableOnly: availableOnly,
        warehouseCode: warehouseCode,
      );
    }

    // Keep direct SKU search useful too, including when it starts before the
    // rep opens the practice category.
    final isPracticeQuery = categoryCode == _categoryCode ||
        (categoryCode == null && search.trim().length >= 2);
    if (!isPracticeQuery) {
      return _real.getMaterials(
        categoryCode: categoryCode,
        selection: selection,
        page: page,
        pageSize: pageSize,
        search: search,
        sortBy: sortBy,
        availableOnly: availableOnly,
        warehouseCode: warehouseCode,
      );
    }

    final selectedMaterial = selection.valueFor(_stepKey);
    final query = search.trim().toLowerCase();
    var matches = OrderPracticeData.practiceMaterials.where((product) {
      if (selectedMaterial != null &&
          product.materialNumber != selectedMaterial) {
        return false;
      }
      if (availableOnly && !product.isAvailable) return false;
      return query.isEmpty ||
          product.searchableValues
              .any((value) => value.toLowerCase().contains(query));
    }).toList();

    switch (sortBy) {
      case ProductSortBy.nameAsc:
        matches.sort((a, b) => a.name.compareTo(b.name));
      case ProductSortBy.priceAsc:
        matches.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      case ProductSortBy.priceDesc:
        matches.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
      case ProductSortBy.stockDesc:
        matches
            .sort((a, b) => b.availableQuantity.compareTo(a.availableQuantity));
      case ProductSortBy.relevance:
        break;
    }

    final start = ((page - 1).clamp(0, matches.length) * pageSize).toInt();
    final end = (start + pageSize).clamp(0, matches.length);
    return Success<PagedResult<Product>>(PagedResult<Product>(
      items: matches.sublist(start, end),
      page: page,
      hasMore: end < matches.length,
    ));
  }
}
