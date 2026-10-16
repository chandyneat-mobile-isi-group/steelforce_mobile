import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/catalog_dao.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';

ProductsCompanion _product({
  required String id,
  String name = 'Rebar',
  String code = 'P',
  String barcode = 'B',
  String sku = 'SKU',
  String brand = 'ISI',
  String categoryId = 'cat1',
  bool deleted = false,
}) {
  return ProductsCompanion.insert(
    id: id,
    familyId: 'f1',
    familyName: 'Family',
    code: '$code-$id',
    sku: '$sku-$id',
    materialCode: 'M-$id',
    barcode: '$barcode-$id',
    name: name,
    description: 'desc',
    categoryId: categoryId,
    subCategory: 'sub',
    brand: brand,
    grade: 'G1',
    material: 'steel',
    size: '12mm',
    diameter: 12,
    thickness: 0,
    length: 6,
    width: 0,
    height: 0,
    weight: 5,
    unit: 'pcs',
    warehouseCode: 'WH1',
    territory: 'Phnom Penh',
    businessUnit: 'BU1',
    imageUrl: '',
    updatedAt: DateTime.utc(2026, 1, 1),
    deleted: Value(deleted),
  );
}

void main() {
  late AppDatabase db;
  late CatalogDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.catalogDao;
  });
  tearDown(() => db.close());

  test('records the current schema version on create', () async {
    expect(await db.appMetadataDao.getValue('schema.version'),
        '$kCurrentSchemaVersion');
  });

  test('upsertProducts inserts then updates by id', () async {
    await dao.upsertProducts([_product(id: '1', name: 'Rebar')]);
    await dao.upsertProducts([_product(id: '1', name: 'Rebar HD')]);
    expect((await dao.getById('1'))!.name, 'Rebar HD');
  });

  test('browse filters deleted + category and LIKE-searches', () async {
    await dao.upsertProducts([
      _product(id: '1', name: 'Rebar', categoryId: 'steel'),
      _product(id: '2', name: 'Wire', categoryId: 'steel'),
      _product(id: '3', name: 'Pipe', categoryId: 'tubes'),
      _product(id: '4', name: 'Gone', deleted: true, categoryId: 'steel'),
    ]);

    final steel = await dao.browse(page: 0, pageSize: 10, categoryId: 'steel');
    expect(steel.map((p) => p.name), ['Rebar', 'Wire']);

    final search = await dao.browse(page: 0, pageSize: 10, query: 'pip');
    expect(search.single.name, 'Pipe');
  });

  test('browse returns pageSize + 1 for has-more detection', () async {
    await dao.upsertProducts([_product(id: '1'), _product(id: '2')]);
    final rows = await dao.browse(page: 0, pageSize: 1);
    expect(rows.length, 2);
  });

  test('getByBarcode resolves a single product', () async {
    await dao.upsertProducts([_product(id: '1', barcode: 'X')]);
    final found = await dao.getByBarcode('X-1');
    expect(found?.id, '1');
    expect(await dao.getByBarcode('missing'), isNull);
  });

  test('prices and stock reference products and round-trip', () async {
    await dao.upsertProducts([_product(id: '1')]);
    await dao.upsertPrices([
      PricesCompanion.insert(
        productId: '1',
        costPrice: 10,
        standardPrice: 15,
        wholesalePrice: 13,
        dealerPrice: 12,
        vipPrice: 11,
        creditPrice: 16,
        cashPrice: 14,
        currency: 'USD',
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await dao.upsertStock([
      StockCompanion.insert(
        productId: '1',
        warehouseCode: 'WH1',
        quantity: 100,
        reserved: 5,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      StockCompanion.insert(
        productId: '1',
        warehouseCode: 'WH2',
        quantity: 20,
        reserved: 0,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);

    expect((await dao.getPrice('1'))!.standardPrice, 15);
    final stock = await dao.getWarehouseStock('1');
    expect(stock.length, 2);
    expect(stock.map((s) => s.warehouseCode)..toList(),
        containsAll(['WH1', 'WH2']));
  });

  test('categories list ordered by sortOrder', () async {
    await dao.upsertCategories([
      CategoriesCompanion.insert(id: 'b', name: 'B', sortOrder: const Value(2)),
      CategoriesCompanion.insert(id: 'a', name: 'A', sortOrder: const Value(1)),
    ]);
    final cats = await dao.fetchCategories();
    expect(cats.map((c) => c.id), ['a', 'b']);
  });

  test('markDeleted hides products', () async {
    await dao.upsertProducts([_product(id: '1'), _product(id: '2')]);
    await dao.markDeleted(['1']);
    expect(await dao.getById('1'), isNull);
    final rows = await dao.browse(page: 0, pageSize: 10);
    expect(rows.map((p) => p.id), ['2']);
  });

  group('read-side state', () {
    setUp(() async {
      await dao.upsertProducts([_product(id: '1'), _product(id: '2')]);
    });

    test('toggleFavorite adds then removes', () async {
      await dao.toggleFavorite('1');
      expect((await dao.fetchFavorites()).single.id, '1');
      await dao.toggleFavorite('1');
      expect(await dao.fetchFavorites(), isEmpty);
    });

    test('recordViewed is idempotent and feeds fetchRecent', () async {
      await dao.recordViewed('1');
      await dao.recordViewed('1');
      await dao.recordViewed('2');
      final recent = await dao.fetchRecent();
      expect(recent.map((p) => p.id), containsAll(['1', '2']));
      expect(recent.length, 2);
    });

    test('sync metadata round-trips', () async {
      expect(await dao.getLastSyncedAt('products'), isNull);
      final at = DateTime.utc(2026, 7, 14, 8);
      await dao.setLastSyncedAt('products', at);
      expect(await dao.getLastSyncedAt('products'), at);
    });
  });
}
