import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/features/order/data/local/product_drift_local_data_source.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';

ProductModel _product({
  required String id,
  String code = 'CODE',
  String name = 'Rebar',
  String brand = 'ISI',
  String categoryId = 'steel',
  String warehouseCode = 'WH1',
  String barcode = 'BC',
  double standardPrice = 15,
  double? promotionPrice,
  double quantity = 100,
  double reserved = 0,
}) {
  return ProductModel(
    id: id,
    familyId: 'fam',
    familyName: 'Family',
    code: code,
    sku: 'SKU-$id',
    materialCode: 'M-$id',
    barcode: barcode,
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
    warehouseCode: warehouseCode,
    territory: 'Phnom Penh',
    businessUnit: 'BU1',
    imageUrl: '',
    isMto: false,
    status: ProductStatus.active,
    updatedAt: DateTime.utc(2026, 1, 1),
    pricing: ProductPricing(
      costPrice: 10,
      standardPrice: standardPrice,
      wholesalePrice: 13,
      dealerPrice: 12,
      vipPrice: 11,
      creditPrice: 16,
      cashPrice: 14,
      currency: 'USD',
      promotionPrice: promotionPrice,
    ),
    stockQuantity: quantity,
    reservedQuantity: reserved,
    minStock: 0,
    maxStock: 0,
  );
}

void main() {
  late AppDatabase db;
  late ProductDriftLocalDataSource source;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    source = ProductDriftLocalDataSource(db.catalogDao);
  });
  tearDown(() => db.close());

  test('upsert + getById round-trips product, pricing and stock', () async {
    await source.upsertProducts([
      _product(id: '1', standardPrice: 20, quantity: 50, reserved: 5),
    ]);
    final p = await source.getById('1');
    expect(p, isNotNull);
    expect(p!.pricing.standardPrice, 20);
    expect(p.stockQuantity, 50);
    expect(p.reservedQuantity, 5);
    expect(p.status, ProductStatus.active);
    expect(p.updatedAt, DateTime.utc(2026, 1, 1));
  });

  test('browse filters by category and sorts by name', () async {
    await source.upsertProducts([
      _product(id: '1', name: 'Bravo', categoryId: 'steel'),
      _product(id: '2', name: 'Alpha', categoryId: 'steel'),
      _product(id: '3', name: 'Pipe', categoryId: 'tubes'),
    ]);
    final rows = await source.browse(
      page: 0,
      pageSize: 10,
      filter: const ProductFilter(
          categoryId: 'steel', sortBy: ProductSortBy.nameAsc),
    );
    expect(rows.map((p) => p.name), ['Alpha', 'Bravo']);
  });

  test('browse availableOnly excludes out-of-stock', () async {
    await source.upsertProducts([
      _product(id: '1', name: 'InStock', quantity: 10, reserved: 0),
      _product(id: '2', name: 'Sold', quantity: 5, reserved: 5),
    ]);
    final rows = await source.browse(
      page: 0,
      pageSize: 10,
      filter: const ProductFilter(availableOnly: true),
    );
    expect(rows.map((p) => p.name), ['InStock']);
  });

  test('count matches filtered result set', () async {
    await source.upsertProducts([
      _product(id: '1', brand: 'ISI'),
      _product(id: '2', brand: 'ISI'),
      _product(id: '3', brand: 'Other'),
    ]);
    expect(await source.count(filter: const ProductFilter(brand: 'ISI')), 2);
  });

  test('getByBarcode and fetchBrands', () async {
    await source.upsertProducts([
      _product(id: '1', barcode: 'XYZ', brand: 'ISI'),
      _product(id: '2', barcode: 'ABC', brand: 'Kliklok'),
    ]);
    expect((await source.getByBarcode('XYZ'))!.id, '1');
    expect(await source.fetchBrands(), ['ISI', 'Kliklok']);
  });

  test('getRowsByCode returns each warehouse row', () async {
    await source.upsertProducts([
      _product(id: '1', code: 'REBAR12', warehouseCode: 'WH1'),
      _product(id: '2', code: 'REBAR12', warehouseCode: 'WH2'),
    ]);
    final rows = await source.getRowsByCode('REBAR12');
    expect(rows.map((p) => p.warehouseCode), ['WH1', 'WH2']);
  });

  test('favorites and recent round-trip through joins', () async {
    await source.upsertProducts([_product(id: '1')]);
    await source.toggleFavorite('1');
    expect((await source.fetchFavorites()).single.id, '1');

    await source.recordViewed('1');
    expect((await source.fetchRecent()).single.id, '1');
  });

  test('sync metadata round-trips and markDeleted hides products', () async {
    await source.upsertProducts([_product(id: '1'), _product(id: '2')]);
    final at = DateTime.utc(2026, 7, 14, 9);
    await source.setLastSyncedAt('products', at);
    expect(await source.getLastSyncedAt('products'), at);

    await source.markDeleted(['1']);
    expect(await source.getById('1'), isNull);
    expect(await source.count(), 1);
  });
}
