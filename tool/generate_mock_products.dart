import 'dart:convert';
import 'dart:io';

import 'package:steelforce/features/order/data/mock/mock_product_data.dart';

/// Writes `assets/mock/products.json`, the demo catalog dataset that
/// `MockProductRemoteDataSource` simulates syncing from.
///
/// Run with: `dart run tool/generate_mock_products.dart [--seed=7]`
///
/// **This is not optional after editing the mock data.**
/// `MockProductRemoteDataSource` only falls back to `MockProductData` in
/// memory when the asset is *missing*. Change `isi_demo_catalog.dart` or
/// `mock_product_data.dart`, rebuild without re-running this, and the app
/// keeps serving the previous catalog from the committed JSON — which looks
/// exactly like "my changes didn't work".
///
/// Row count isn't a direct parameter — it falls out of `MockProductData`'s
/// composed generators:
///
///  * `IsiDemoCatalog` contributes a fixed 60 rows (10 categories x 6
///    hand-picked real SKUs), the set the guided configurator is walked
///    against;
///  * [ProductGenerator] / [VariantGenerator] / [WarehouseGenerator]
///    contribute the traded catalog — 113 families x 5-80 variants x 2-4
///    warehouses each, ~11,000 rows.
///
/// The same generators scale to millions on a real backend without this
/// script changing shape.
///
/// Two invariants are checked after writing, because both have already been
/// broken once and neither fails loudly on its own:
///
///  1. **Total rows land in the 10k-30k band** the paging and scroll
///     performance tests are calibrated against. Trimming a brand list or a
///     rating series can quietly drop the fixture under that floor.
///  2. **No `cat_isi_*` category id collides with a generated one.** Facet
///     options are `SELECT DISTINCT` aggregates scoped to a category, so a
///     single generated row landing in a demo category injects invented
///     values into the guided flow and destroys the "six SKUs, walkable by
///     hand" property the demo catalog exists to provide. This one is
///     invisible in the JSON and only shows up as a picker that offers
///     gauges no demo SKU has.
///
/// The file is written before validation runs, so a failure still leaves the
/// output on disk to inspect. Exit code is non-zero so CI notices.
void main(List<String> args) {
  var seed = 7;
  for (final arg in args) {
    if (arg.startsWith('--seed=')) seed = int.parse(arg.substring(7));
  }

  final data = MockProductData.generate(seed: seed);
  final file = File('assets/mock/products.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(data));

  final products = (data['products'] as List).cast<Map<String, dynamic>>();
  final categories = (data['categories'] as List).cast<Map<String, dynamic>>();

  final demoRows =
      products.where((p) => _isDemo(p['categoryId'] as String)).length;
  final generatedRows = products.length - demoRows;

  stdout
    ..writeln('Wrote ${products.length} products across '
        '${categories.length} categories to ${file.path}')
    ..writeln('  demo (isi_demo_catalog):  $demoRows')
    ..writeln('  generated (traded):       $generatedRows');

  final problems = <String>[
    ..._checkRowCount(products.length),
    ..._checkNoCategoryCollision(categories, products),
  ];

  if (problems.isEmpty) return;
  for (final problem in problems) {
    stderr.writeln('ERROR: $problem');
  }
  exitCode = 1;
}

bool _isDemo(String categoryId) => categoryId.startsWith('cat_isi_');

List<String> _checkRowCount(int rows) {
  const min = 10000;
  const max = 30000;
  if (rows >= min && rows <= max) return const [];
  return [
    'row count $rows is outside the $min-$max band the paging tests assume. '
        'Widen or narrow a rating series in VariantGenerator, or the warehouse '
        'spread in WarehouseGenerator.',
  ];
}

/// The generated trading catalog and the hand-written demo catalog must stay
/// in disjoint categories. Checks both the declared category list and the
/// rows themselves, since a leaf spec pointing at the wrong id would produce
/// products in a demo category without duplicating the category row.
List<String> _checkNoCategoryCollision(
  List<Map<String, dynamic>> categories,
  List<Map<String, dynamic>> products,
) {
  final problems = <String>[];

  final seen = <String>{};
  for (final category in categories) {
    final id = category['id'] as String;
    if (!seen.add(id)) {
      problems.add('duplicate category id "$id"');
    }
  }

  final demoCategoryIds =
      categories.map((c) => c['id'] as String).where(_isDemo).toSet();

  final strays = <String>{};
  for (final product in products) {
    final categoryId = product['categoryId'] as String;
    if (!_isDemo(categoryId)) continue;
    final code = product['code'] as String;
    // Every demo row's code is 'M<sap material number>'; anything else in a
    // cat_isi_* category came from the generator.
    if (!RegExp(r'^M\d+$').hasMatch(code)) strays.add(categoryId);
  }
  for (final categoryId in strays) {
    problems.add(
      'generated products landed in demo category "$categoryId" — check the '
      'categoryId on the matching _LeafSpec in ProductGenerator',
    );
  }

  final declared = categories.map((c) => c['id'] as String).toSet();
  final orphans = products
      .map((p) => p['categoryId'] as String)
      .where((id) => !declared.contains(id))
      .toSet();
  for (final id in orphans) {
    problems.add('products reference undeclared category "$id"');
  }

  if (demoCategoryIds.length != 10) {
    problems.add(
      'expected 10 cat_isi_* categories, found ${demoCategoryIds.length} — '
      'isi_demo_catalog.dart and this check have drifted apart',
    );
  }

  return problems;
}
