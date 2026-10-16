import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Everything the Product Filter screen restores after navigation: the active
/// [filter], the [query] text, and the line-item [unit]/[quantity] defaults.
class CatalogFilterSnapshot {
  const CatalogFilterSnapshot({
    this.filter = const ProductFilter(),
    this.query = '',
    this.unit = 'Pc',
    this.quantity = 1,
  });

  final ProductFilter filter;
  final String query;
  final String unit;
  final int quantity;
}

/// Persists the last [CatalogFilterSnapshot] so the filter experience is
/// restored verbatim after the user navigates away and back (spec: "remember
/// selected category/size/unit/quantity/…, restore after navigation").
///
/// Serialization lives here in the data layer — the [ProductFilter] entity
/// stays pure. Reads are synchronous (Hive keeps the box in memory) so the
/// screen can seed its initial state without an async gap or a loading flash.
class CatalogFilterStore {
  const CatalogFilterStore(this._box);
  final Box<dynamic> _box;

  static const _kSnapshot = 'catalog_filter_snapshot';

  /// Restores the persisted snapshot, falling back to a clean default if
  /// nothing is stored or the stored blob is unreadable.
  CatalogFilterSnapshot load() {
    final raw = _box.get(_kSnapshot);
    if (raw is! String) return const CatalogFilterSnapshot();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CatalogFilterSnapshot(
        filter: _filterFromMap(map['filter'] as Map<String, dynamic>? ?? {}),
        query: map['query'] as String? ?? '',
        unit: map['unit'] as String? ?? 'Pc',
        quantity: map['quantity'] as int? ?? 1,
      );
    } catch (_) {
      return const CatalogFilterSnapshot();
    }
  }

  Future<void> save(CatalogFilterSnapshot snapshot) => _box.put(
        _kSnapshot,
        jsonEncode({
          'filter': _filterToMap(snapshot.filter),
          'query': snapshot.query,
          'unit': snapshot.unit,
          'quantity': snapshot.quantity,
        }),
      );

  Future<void> clear() => _box.delete(_kSnapshot);

  Map<String, dynamic> _filterToMap(ProductFilter f) => {
        'categoryId': f.categoryId,
        'subCategory': f.subCategory,
        'brand': f.brand,
        'warehouseCode': f.warehouseCode,
        'availableOnly': f.availableOnly,
        'sortBy': f.sortBy.name,
        'size': f.size,
        'length': f.length,
        'width': f.width,
        'height': f.height,
        'grade': f.grade,
        'diameter': f.diameter,
        'thickness': f.thickness,
        'material': f.material,
      };

  ProductFilter _filterFromMap(Map<String, dynamic> m) => ProductFilter(
        categoryId: m['categoryId'] as String?,
        subCategory: m['subCategory'] as String?,
        brand: m['brand'] as String?,
        warehouseCode: m['warehouseCode'] as String?,
        availableOnly: m['availableOnly'] as bool? ?? false,
        sortBy: ProductSortBy.values.asNameMap()[m['sortBy']] ??
            ProductSortBy.relevance,
        size: m['size'] as String?,
        length: (m['length'] as num?)?.toDouble(),
        width: (m['width'] as num?)?.toDouble(),
        height: (m['height'] as num?)?.toDouble(),
        grade: m['grade'] as String?,
        diameter: (m['diameter'] as num?)?.toDouble(),
        thickness: (m['thickness'] as num?)?.toDouble(),
        material: m['material'] as String?,
      );
}
