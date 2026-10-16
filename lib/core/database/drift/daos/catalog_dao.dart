import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/catalog_tables.dart';

part 'catalog_dao.g.dart';

/// Sort options for the joined product queries.
enum ProductQuerySort { relevance, nameAsc, priceAsc, priceDesc, stockDesc }

/// Neutral browse/count criteria for the joined product queries — the Order
/// feature maps its `ProductFilter` onto this so the core DAO stays decoupled.
class ProductQuery {
  const ProductQuery({
    this.query = '',
    this.page = 0,
    this.pageSize = 30,
    this.categoryId,
    this.familyId,
    this.subCategory,
    this.brand,
    this.warehouseCode,
    this.size,
    this.length,
    this.width,
    this.height,
    this.grade,
    this.diameter,
    this.thickness,
    this.material,
    this.availableOnly = false,
    this.sort = ProductQuerySort.relevance,
  });

  final String query;
  final int page;
  final int pageSize;
  final String? categoryId;
  final String? familyId;
  final String? subCategory;
  final String? brand;
  final String? warehouseCode;
  final String? size;
  final double? length;
  final double? width;
  final double? height;
  final String? grade;
  final double? diameter;
  final double? thickness;
  final String? material;
  final bool availableOnly;
  final ProductQuerySort sort;
}

/// One distinct value of a filterable product column, with how many catalog
/// rows still match if it is selected. Neutral row shape — the Order feature
/// maps it onto its own `FilterOption` entity.
class CatalogFacetValue {
  const CatalogFacetValue({
    required this.value,
    required this.label,
    required this.matchCount,
  });

  final String value;
  final String label;
  final int matchCount;
}

/// Scoped accessor for the offline product catalog master data. Reads exclude
/// soft-deleted products. Search uses LIKE (FTS5 is a planned optimization).
@DriftAccessor(tables: [
  Categories,
  Products,
  Prices,
  Stock,
  ProductFavorites,
  RecentProducts,
  CatalogSyncMeta,
])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  // ── Sync writes ────────────────────────────────────────────────────

  Future<void> upsertCategories(List<CategoriesCompanion> rows) =>
      _batchUpsert(categories, rows);

  /// Products must be upserted before prices/stock (FK references products).
  Future<void> upsertProducts(List<ProductsCompanion> rows) =>
      _batchUpsert(products, rows);

  Future<void> upsertPrices(List<PricesCompanion> rows) =>
      _batchUpsert(prices, rows);

  Future<void> upsertStock(List<StockCompanion> rows) =>
      _batchUpsert(stock, rows);

  Future<void> _batchUpsert<T extends Table, D>(
    TableInfo<T, D> table,
    List<Insertable<D>> rows,
  ) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(table, rows));
  }

  /// Deletes every category *except* [keepIds] — the categories the feed just
  /// published.
  ///
  /// Categories have no `deleted` flag (they are SAP-controlled reference data
  /// replaced wholesale on sync, not a syncable entity), so a taxonomy change
  /// leaves the retired rows behind. That matters because the product finder
  /// opens on "categories that have products": a stale row whose products were
  /// re-pointed at a new id shows up as a category that dead-ends immediately.
  ///
  /// Refuses an empty [keepIds] rather than treating it as "keep nothing" — a
  /// feed that failed to parse must not be able to wipe the taxonomy.
  Future<void> pruneCategoriesNotIn(List<String> keepIds) async {
    if (keepIds.isEmpty) return;
    await (delete(categories)..where((t) => t.id.isNotIn(keepIds))).go();
  }

  Future<void> markDeleted(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(products)..where((t) => t.id.isIn(ids)))
        .write(const ProductsCompanion(deleted: Value(true)));
  }

  // ── Catalog reads ──────────────────────────────────────────────────

  /// Paginated browse: returns up to `pageSize + 1` rows for has-more
  /// detection. Optional category/brand filters and a LIKE search over
  /// code/name/barcode/sku/brand.
  Future<List<Product>> browse({
    required int page,
    required int pageSize,
    String query = '',
    String? categoryId,
    String? brand,
  }) {
    final statement = select(products)
      ..where((t) {
        var cond = t.deleted.equals(false);
        if (categoryId != null) cond = cond & t.categoryId.equals(categoryId);
        if (brand != null) cond = cond & t.brand.equals(brand);
        final trimmed = query.trim();
        if (trimmed.isNotEmpty) {
          final like = '%$trimmed%';
          cond = cond &
              (t.code.like(like) |
                  t.name.like(like) |
                  t.barcode.like(like) |
                  t.sku.like(like) |
                  t.brand.like(like));
        }
        return cond;
      })
      ..orderBy([(t) => OrderingTerm(expression: t.name)])
      ..limit(pageSize + 1, offset: page * pageSize);
    return statement.get();
  }

  Future<Product?> getById(String id) {
    return (select(products)
          ..where((t) => t.id.equals(id) & t.deleted.equals(false)))
        .getSingleOrNull();
  }

  Future<Product?> getByBarcode(String barcode) {
    return (select(products)
          ..where((t) => t.barcode.equals(barcode) & t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<Product>> getByCategory(String categoryId) {
    return (select(products)
          ..where(
              (t) => t.categoryId.equals(categoryId) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<List<Category>> fetchCategories() {
    return (select(categories)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  Future<Price?> getPrice(String productId) {
    return (select(prices)..where((t) => t.productId.equals(productId)))
        .getSingleOrNull();
  }

  /// All warehouse stock rows for a product.
  Future<List<StockData>> getWarehouseStock(String productId) {
    return (select(stock)..where((t) => t.productId.equals(productId))).get();
  }

  // ── Favorites / recent (local UI state) ────────────────────────────

  Future<void> toggleFavorite(String productId) async {
    final existing = await (select(productFavorites)
          ..where((t) => t.productId.equals(productId)))
        .getSingleOrNull();
    if (existing != null) {
      await (delete(productFavorites)
            ..where((t) => t.productId.equals(productId)))
          .go();
    } else {
      await into(productFavorites).insert(
        ProductFavoritesCompanion.insert(
          productId: productId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<List<Product>> fetchFavorites() {
    final query = select(productFavorites).join([
      innerJoin(products, products.id.equalsExp(productFavorites.productId)),
    ])
      ..where(products.deleted.equals(false))
      ..orderBy([
        OrderingTerm(
            expression: productFavorites.createdAt, mode: OrderingMode.desc)
      ]);
    return query.map((row) => row.readTable(products)).get();
  }

  Future<void> recordViewed(String productId) {
    return into(recentProducts).insertOnConflictUpdate(
      RecentProductsCompanion.insert(
        productId: productId,
        viewedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<Product>> fetchRecent({int limit = 20}) {
    final query = select(recentProducts).join([
      innerJoin(products, products.id.equalsExp(recentProducts.productId)),
    ])
      ..where(products.deleted.equals(false))
      ..orderBy([
        OrderingTerm(
            expression: recentProducts.viewedAt, mode: OrderingMode.desc)
      ])
      ..limit(limit);
    return query.map((row) => row.readTable(products)).get();
  }

  // ── Sync metadata ──────────────────────────────────────────────────

  Future<DateTime?> getLastSyncedAt(String entity) async {
    final row = await (select(catalogSyncMeta)
          ..where((t) => t.entity.equals(entity)))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> setLastSyncedAt(String entity, DateTime at) {
    return into(catalogSyncMeta).insertOnConflictUpdate(
      CatalogSyncMetaCompanion.insert(
        entity: entity,
        lastSyncedAt: Value(at),
      ),
    );
  }

  // ── Joined product queries (product + price + own-warehouse stock) ──
  //
  // These reproduce the legacy `catalog.db` SELECTs verbatim (same aliases) so
  // the Order feature's `ProductModel.fromRow` maps each `QueryRow.data`
  // unchanged. Full-text `MATCH` is replaced by a LIKE scan (FTS5 is a planned
  // optimization); everything else — the price/stock joins, availability guard
  // and COALESCE-based price/stock sorts — is preserved.

  static const String _productCols = '''
    p.*, pr.cost_price, pr.standard_price, pr.wholesale_price, pr.dealer_price,
    pr.vip_price, pr.credit_price, pr.cash_price, pr.promotion_price,
    pr.promotion_type, pr.promotion_label, pr.currency,
    s.quantity AS stock_quantity, s.reserved AS reserved_quantity''';

  static const String _productJoins = '''
    FROM products p
    LEFT JOIN prices pr ON pr.product_id = p.id
    LEFT JOIN stock s ON s.product_id = p.id AND s.warehouse_code = p.warehouse_code''';

  Set<ResultSetImplementation<dynamic, dynamic>> get _productReads =>
      {products, prices, stock};

  Future<List<QueryRow>> browseProducts(ProductQuery q) {
    final (where, vars) = _productWhere(q);
    final sql = 'SELECT $_productCols $_productJoins WHERE $where '
        'ORDER BY ${_productOrder(q.sort)} LIMIT ? OFFSET ?';
    return customSelect(
      sql,
      variables: [
        ...vars,
        Variable(q.pageSize + 1),
        Variable(q.page * q.pageSize)
      ],
      readsFrom: _productReads,
    ).get();
  }

  Future<int> countProducts(ProductQuery q) async {
    final (where, vars) = _productWhere(q);
    final row = await customSelect(
      'SELECT COUNT(*) AS c $_productJoins WHERE $where',
      variables: vars,
      readsFrom: _productReads,
    ).getSingle();
    return row.read<int>('c');
  }

  Future<QueryRow?> productById(String id) {
    return customSelect(
      'SELECT $_productCols $_productJoins WHERE p.id = ? AND p.deleted = 0 LIMIT 1',
      variables: [Variable(id)],
      readsFrom: _productReads,
    ).getSingleOrNull();
  }

  Future<QueryRow?> productByBarcode(String barcode) {
    return customSelect(
      'SELECT $_productCols $_productJoins WHERE p.barcode = ? AND p.deleted = 0 LIMIT 1',
      variables: [Variable(barcode)],
      readsFrom: _productReads,
    ).getSingleOrNull();
  }

  /// One representative row per distinct `code` within a family.
  Future<List<QueryRow>> variantRowsByFamily(String familyId) {
    return customSelect(
      'SELECT $_productCols $_productJoins '
      'WHERE p.family_id = ? AND p.deleted = 0 GROUP BY p.code ORDER BY p.name ASC',
      variables: [Variable(familyId)],
      readsFrom: _productReads,
    ).get();
  }

  /// Every warehouse row sharing a `code`.
  Future<List<QueryRow>> rowsByCode(String code) {
    return customSelect(
      'SELECT $_productCols $_productJoins '
      'WHERE p.code = ? AND p.deleted = 0 ORDER BY p.warehouse_code ASC',
      variables: [Variable(code)],
      readsFrom: _productReads,
    ).get();
  }

  Future<List<QueryRow>> favoriteProductRows() {
    return customSelect(
      'SELECT $_productCols FROM favorites fav '
      'JOIN products p ON p.id = fav.product_id '
      'LEFT JOIN prices pr ON pr.product_id = p.id '
      'LEFT JOIN stock s ON s.product_id = p.id AND s.warehouse_code = p.warehouse_code '
      'WHERE p.deleted = 0 ORDER BY fav.created_at DESC',
      readsFrom: {productFavorites, ..._productReads},
    ).get();
  }

  Future<List<QueryRow>> recentProductRows({int limit = 20}) {
    return customSelect(
      'SELECT $_productCols FROM recent_products rp '
      'JOIN products p ON p.id = rp.product_id '
      'LEFT JOIN prices pr ON pr.product_id = p.id '
      'LEFT JOIN stock s ON s.product_id = p.id AND s.warehouse_code = p.warehouse_code '
      'WHERE p.deleted = 0 ORDER BY rp.viewed_at DESC LIMIT ?',
      variables: [Variable(limit)],
      readsFrom: {recentProducts, ..._productReads},
    ).get();
  }

  /// One level of the guided filter flow: the distinct values of a single
  /// product column among the rows still matching [q], with how many rows each
  /// value keeps alive.
  ///
  /// This is deliberately *not* a product read — it returns at most a few dozen
  /// short strings regardless of catalog size, which is what lets the guided
  /// flow walk a 100k-SKU catalog without paging a single product until the
  /// last step is answered. [facet] is resolved against [facetColumns] rather
  /// than interpolated from caller input, so no caller can shape the SQL.
  ///
  /// Values come back as TEXT even for the REAL columns (`CAST`), so callers
  /// get one uniform signature; numeric parsing belongs to the layer that knows
  /// the attribute's type.
  Future<List<CatalogFacetValue>> distinctFacetValues({
    required String facet,
    required ProductQuery q,
  }) async {
    final spec = facetColumns[facet];
    if (spec == null) {
      throw ArgumentError.value(facet, 'facet', 'Not a filterable facet');
    }
    final (valueCol, labelSpec, isNumeric) = spec;
    final labelCol = labelSpec ?? valueCol;
    // A numeric column carries 0 for "not applicable to this product type"
    // (a steel sheet has no length), which is an absence, not a value — so it
    // must never surface as a selectable option.
    final blank =
        isNumeric ? 'p.$valueCol > 0' : "CAST(p.$valueCol AS TEXT) != ''";
    final (where, vars) = _productWhere(q);
    final rows = await customSelect(
      'SELECT CAST(p.$valueCol AS TEXT) AS facet_value, '
      'CAST(MIN(p.$labelCol) AS TEXT) AS facet_label, COUNT(*) AS facet_count '
      '$_productJoins WHERE $where '
      'AND p.$valueCol IS NOT NULL AND $blank '
      'GROUP BY p.$valueCol ORDER BY p.$valueCol ASC',
      variables: vars,
      readsFrom: _productReads,
    ).get();
    return rows
        .map((r) => CatalogFacetValue(
              value: r.read<String>('facet_value'),
              label: r.read<String>('facet_label'),
              matchCount: r.read<int>('facet_count'),
            ))
        .toList();
  }

  /// Whitelist of columns [distinctFacetValues] may group by, keyed by the
  /// neutral facet name callers use:
  /// `(value column, label column or null when identical, is numeric)`.
  static const Map<String, (String, String?, bool)> facetColumns = {
    'family': ('family_id', 'family_name', false),
    // Which plants/warehouses still hold something matching. A product row is
    // a SKU at one warehouse, so this is the facet that separates otherwise
    // identical result rows.
    'warehouse': ('warehouse_code', null, false),
    'subCategory': ('sub_category', null, false),
    'brand': ('brand', null, false),
    'size': ('size', null, false),
    'grade': ('grade', null, false),
    'material': ('material', null, false),
    'length': ('length', null, true),
    'width': ('width', null, true),
    'height': ('height', null, true),
    'diameter': ('diameter', null, true),
    'thickness': ('thickness', null, true),
  };

  /// Categories that actually hold at least one live product. The guided
  /// configurator opens on this rather than the full taxonomy — offering a
  /// category whose every branch dead-ends is the same defect as offering an
  /// option that matches nothing.
  Future<List<Category>> categoriesWithProducts() async {
    final rows = await customSelect(
      'SELECT c.* FROM categories c '
      'WHERE EXISTS (SELECT 1 FROM products p '
      '              WHERE p.category_id = c.id AND p.deleted = 0) '
      'ORDER BY c.sort_order ASC, c.name ASC',
      readsFrom: {categories, products},
    ).get();
    return rows.map((r) => categories.map(r.data)).toList();
  }

  Future<List<String>> distinctBrands() async {
    final rows = await customSelect(
      'SELECT DISTINCT brand FROM products WHERE deleted = 0 ORDER BY brand ASC',
      readsFrom: {products},
    ).get();
    return rows.map((r) => r.read<String>('brand')).toList();
  }

  /// Atomic upsert of a product bundle (master + price + own-warehouse stock).
  Future<void> upsertCatalog({
    required List<ProductsCompanion> productRows,
    required List<PricesCompanion> priceRows,
    required List<StockCompanion> stockRows,
  }) async {
    await transaction(() async {
      await batch((b) {
        b.insertAllOnConflictUpdate(products, productRows);
        b.insertAllOnConflictUpdate(prices, priceRows);
        b.insertAllOnConflictUpdate(stock, stockRows);
      });
    });
  }

  (String, List<Variable>) _productWhere(ProductQuery q) {
    final where = <String>['p.deleted = 0'];
    final vars = <Variable>[];

    void eq(String column, Object? value) {
      if (value == null) return;
      where.add('p.$column = ?');
      vars.add(Variable(value));
    }

    eq('category_id', q.categoryId);
    eq('family_id', q.familyId);
    eq('sub_category', q.subCategory);
    eq('brand', q.brand);
    eq('warehouse_code', q.warehouseCode);
    eq('size', q.size);
    eq('length', q.length);
    eq('width', q.width);
    eq('height', q.height);
    eq('grade', q.grade);
    eq('diameter', q.diameter);
    eq('thickness', q.thickness);
    eq('material', q.material);

    if (q.availableOnly) {
      where.add('(COALESCE(s.quantity, 0) - COALESCE(s.reserved, 0)) > 0');
    }

    // Keep letters of *any* script, digits, and the punctuation that is part
    // of a steel identifier ("1/2\"", "TRIM-7", "0.30").
    //
    // `\w` is ASCII-only, so the previous pattern silently deleted every Khmer
    // character: a rep searching ស័ង្កសី got an empty query, which reads as
    // "no text filter" and returns the whole catalog. SAP carries a Khmer
    // description on every material and reps search in it, so this is a
    // correctness fix, not a nicety.
    //
    // `\p{M}` is not optional: Khmer builds a syllable from a base consonant
    // plus combining marks (ស + ័ + ្ + ក …), all of which are category M.
    // Dropping them doesn't just lose accents, it shatters one word into
    // several space-separated consonants that LIKE can never match again.
    final sanitized = q.query
        .replaceAll(RegExp(r'[^\p{L}\p{N}\p{M}\s./-]', unicode: true), ' ')
        .trim();
    if (sanitized.isNotEmpty) {
      final like = '%$sanitized%';
      // Every identifier a rep might have in front of them: what's printed on
      // the tag (code/barcode/SKU), what SAP calls it (material code), and
      // what it's described as in either language (name/description carry the
      // localised text until a dedicated Khmer-name column exists).
      // Both languages, always — not the active locale's column only.
      //
      // A rep with the UI in English who types a Khmer product name is looking
      // for that product; returning nothing would be a defect, not correct
      // locale handling. Searching both costs one more `OR` on an already
      // indexed scan and removes a whole class of "it's not in the app"
      // support calls.
      const columns = [
        'code',
        'name', // SAP MaterialDes (English)
        'name_kh', // SAP MaterialDesKH
        'barcode',
        'sku',
        'brand',
        'material_code',
        'description',
        'specification',
        'color',
        'size',
        'grade',
      ];
      where.add('(${columns.map((c) => 'p.$c LIKE ?').join(' OR ')})');
      for (var i = 0; i < columns.length; i++) {
        vars.add(Variable(like));
      }
    }
    return (where.join(' AND '), vars);
  }

  String _productOrder(ProductQuerySort sort) => switch (sort) {
        ProductQuerySort.nameAsc => 'p.name ASC',
        ProductQuerySort.priceAsc =>
          'COALESCE(pr.promotion_price, pr.standard_price, 0) ASC',
        ProductQuerySort.priceDesc =>
          'COALESCE(pr.promotion_price, pr.standard_price, 0) DESC',
        ProductQuerySort.stockDesc =>
          '(COALESCE(s.quantity, 0) - COALESCE(s.reserved, 0)) DESC',
        ProductQuerySort.relevance => 'p.updated_at DESC',
      };
}
