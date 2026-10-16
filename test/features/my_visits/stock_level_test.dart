import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';

/// The three-tier stock status: storage round-trip and the data-layer SAP
/// payload mapping (the UI never sees SAP codes — repository isolation).
void main() {
  group('StockLevel storage parsing', () {
    test('round-trips every level through its storage name', () {
      for (final level in StockLevel.values) {
        expect(StockLevel.parse(level.storageName), level);
      }
    });

    test('unknown or legacy values degrade to low, never crash', () {
      expect(StockLevel.parse(null), StockLevel.low);
      expect(StockLevel.parse(''), StockLevel.low);
      expect(StockLevel.parse('42'), StockLevel.low);
      expect(StockLevel.parse('OUT_OF_STOCK'), StockLevel.low);
    });
  });

  group('SAP payload mapping (data layer only)', () {
    test('each level has a distinct SAP code', () {
      final codes = StockLevel.values.map((l) => l.sapCode).toSet();
      expect(codes, hasLength(StockLevel.values.length));
    });

    test('codes round-trip through fromSapCode', () {
      for (final level in StockLevel.values) {
        expect(StockLevelSapMapping.fromSapCode(level.sapCode), level);
      }
    });

    test('an unknown inbound code degrades to low', () {
      expect(StockLevelSapMapping.fromSapCode('???'), StockLevel.low);
    });
  });

  group('VisitStockUpdate scoping', () {
    test('a row must belong to exactly one of stop or depot', () {
      expect(
        () => VisitStockUpdateModel(
          id: 'x',
          productId: 'p',
          productName: 'P',
          stockLevel: StockLevel.medium,
          notes: '',
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => VisitStockUpdateModel(
          id: 'x',
          stopId: 's-1',
          depotId: 'd-1',
          productId: 'p',
          productName: 'P',
          stockLevel: StockLevel.medium,
          notes: '',
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
