import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/data/mock/mock_product_data.dart';

/// Guards the single-source rule for mock master data: **every generated
/// record carries both languages on the same row**.
void main() {
  group('product catalog generator', () {
    final data = MockProductData.generate();

    test('every generated product carries a Khmer name', () {
      final products = (data['products'] as List).cast<Map<String, dynamic>>();
      final missing = products
          .where((p) => ((p['nameKh'] as String?) ?? '').trim().isEmpty)
          .toList();
      expect(missing, isEmpty);
    });

    test('every category carries a Khmer name', () {
      final categories =
          (data['categories'] as List).cast<Map<String, dynamic>>();
      final missing = categories
          .where((c) => ((c['nameKh'] as String?) ?? '').trim().isEmpty)
          .toList();
      expect(missing, isEmpty);
    });
  });

  // The generator being correct is not enough — `MockProductRemoteDataSource`
  // serves the committed asset and only falls back to the generator when the
  // file is *missing*, so a stale asset silently wins.
  group('committed assets/mock/products.json', () {
    late Map<String, dynamic> decoded;

    setUpAll(() {
      decoded =
          json.decode(File('assets/mock/products.json').readAsStringSync())
              as Map<String, dynamic>;
    });

    test('is not stale: every product row has a Khmer name', () {
      final products =
          (decoded['products'] as List).cast<Map<String, dynamic>>();
      final missing = products
          .where((p) => ((p['nameKh'] as String?) ?? '').trim().isEmpty)
          .length;
      expect(missing, 0,
          reason: '$missing of ${products.length} rows have no nameKh — '
              're-run `dart run tool/generate_mock_products.dart`');
    });

    test('is not stale: every category row has a Khmer name', () {
      final categories =
          (decoded['categories'] as List).cast<Map<String, dynamic>>();
      expect(
        categories
            .where((c) => ((c['nameKh'] as String?) ?? '').trim().isEmpty)
            .length,
        0,
      );
    });
  });
}
