import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/cart_drift_local_data_source.dart';

DataMap _row(
  String id, {
  String productId = 'P1',
  double quantity = 2,
  double discount = 0,
  String? depotId,
  String createdAt = '2026-01-01T00:00:00.000Z',
}) {
  return {
    'id': id,
    'product_id': productId,
    'quantity': quantity,
    'unit': 'pcs',
    'discount_percent': discount,
    'lead_id': null,
    'depot_id': depotId,
    'editing_quotation_id': null,
    'created_at': createdAt,
  };
}

void main() {
  late AppDatabase db;
  late CartDriftLocalDataSource source;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    source = CartDriftLocalDataSource(db.cartDao);
  });
  tearDown(() => db.close());

  test('upsert then fetch round-trips the DataMap contract', () async {
    await source
        .upsertItem(_row('1', quantity: 3, discount: 10, depotId: 'C1'));
    final rows = await source.fetchCartRows();
    expect(rows.length, 1);
    final r = rows.single;
    expect(r['id'], '1');
    expect(r['product_id'], 'P1');
    expect(r['quantity'], 3.0);
    expect(r['discount_percent'], 10.0);
    expect(r['depot_id'], 'C1');
    expect(r['lead_id'], isNull);
    expect(r['created_at'], '2026-01-01T00:00:00.000Z');
  });

  test('upsert replaces by id', () async {
    await source.upsertItem(_row('1', quantity: 1));
    await source.upsertItem(_row('1', quantity: 9));
    final rows = await source.fetchCartRows();
    expect(rows.length, 1);
    expect(rows.single['quantity'], 9.0);
  });

  test('fetch is ordered by created_at ascending', () async {
    await source.upsertItem(_row('b', createdAt: '2026-01-02T00:00:00.000Z'));
    await source.upsertItem(_row('a', createdAt: '2026-01-01T00:00:00.000Z'));
    final ids = (await source.fetchCartRows()).map((r) => r['id']);
    expect(ids, ['a', 'b']);
  });

  test('removeItem and clearCart', () async {
    await source.upsertItem(_row('1'));
    await source.upsertItem(_row('2'));
    await source.removeItem('1');
    expect((await source.fetchCartRows()).map((r) => r['id']), ['2']);
    await source.clearCart();
    expect(await source.fetchCartRows(), isEmpty);
  });

  test('replaceCart clears then inserts atomically', () async {
    await source.upsertItem(_row('old'));
    await source.replaceCart([_row('new1'), _row('new2')]);
    final ids = (await source.fetchCartRows()).map((r) => r['id']).toList();
    expect(ids, containsAll(['new1', 'new2']));
    expect(ids.contains('old'), isFalse);
  });
}
