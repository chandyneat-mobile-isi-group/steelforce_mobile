import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/catalog_dao.dart';
import 'package:steelforce/features/order/data/local/product_drift_local_data_source.dart';
import 'package:steelforce/features/order/data/local/product_filter_local_data_source.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Exercises the query the guided finder leans on entirely: distinct facet
/// values, narrowed by the answers above, against the real demo catalog.
///
/// Assertions are deliberately about *invariants* rather than specific SAP
/// values. The demo catalog is transcribed from a material-master extract and
/// gets re-derived whenever a fresher one lands; a test that pins "TRIM-7" or
/// "0.30 mm" fails on the next extract without anything actually being broken.
/// What must hold for every extract is asserted here; the one place a literal
/// is needed, it is read back out of the catalog rather than typed in.
void main() {
  late AppDatabase db;
  late ProductDriftLocalDataSource catalog;
  late ProductFilterDriftLocalDataSource facets;

  final categoryIds = IsiDemoCatalog.categories()
      .map((c) => c['id'] as String)
      .toList(growable: false);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    catalog = ProductDriftLocalDataSource(db.catalogDao);
    facets = ProductFilterDriftLocalDataSource(db.catalogDao);

    await catalog.upsertProducts(
      IsiDemoCatalog.products().map(ProductModel.fromJson).toList(),
    );
  });
  tearDown(() => db.close());

  test('every demo category carries exactly six SKUs', () async {
    expect(categoryIds, isNotEmpty);
    for (final category in IsiDemoCatalog.categories()) {
      final rows = await catalog.count(
        filter: ProductFilter(categoryId: category['id'] as String),
      );
      expect(rows, 6, reason: '${category['name']} should have 6 demo SKUs');
    }
  });

  test('every category resolves a family facet that accounts for all six',
      () async {
    for (final categoryId in categoryIds) {
      final families = await facets.facetValues(
        facet: 'family',
        filter: ProductFilter(categoryId: categoryId),
      );

      expect(families, isNotEmpty, reason: '$categoryId has no families');
      expect(
        families.fold<int>(0, (sum, f) => sum + f.matchCount),
        6,
        reason: 'family counts must account for every SKU in $categoryId',
      );
    }
  });

  test('family facet returns the id as value and a readable name as label',
      () async {
    for (final categoryId in categoryIds) {
      final families = await facets.facetValues(
        facet: 'family',
        filter: ProductFilter(categoryId: categoryId),
      );

      for (final family in families) {
        expect(family.value, startsWith('fam_'));
        expect(family.label, isNot(startsWith('fam_')));
        expect(family.label.trim(), isNotEmpty);
      }
    }
  });

  test('answering a step narrows the next one to what actually exists',
      () async {
    for (final categoryId in categoryIds) {
      final families = await facets.facetValues(
        facet: 'family',
        filter: ProductFilter(categoryId: categoryId),
      );
      final family = families.first;

      // Every facet below the family can only ever offer values that survive
      // it — that is the whole dead-end-free guarantee.
      for (final facet in const ['size', 'grade', 'brand', 'subCategory']) {
        final narrowed = await facets.facetValues(
          facet: facet,
          filter: ProductFilter(categoryId: categoryId, familyId: family.value),
        );
        final total = narrowed.fold<int>(0, (sum, f) => sum + f.matchCount);
        if (narrowed.isEmpty) continue;
        expect(total, family.matchCount,
            reason: '$facet under ${family.label} must cover exactly '
                'that family, no more and no less');
      }
    }
  });

  test('numeric facets never offer a zero — that is absence, not a value',
      () async {
    // Several ISI lines carry no length (sheet sold by the metre off a roll,
    // pipe by the stick) or no diameter (anything not round). Those columns sit
    // at 0, and 0 must never surface as a selectable option.
    for (final categoryId in categoryIds) {
      for (final facet in const ['length', 'diameter', 'thickness', 'width']) {
        final values = await facets.facetValues(
          facet: facet,
          filter: ProductFilter(categoryId: categoryId),
        );
        for (final value in values) {
          expect(double.parse(value.value), greaterThan(0),
              reason: '$facet in $categoryId offered a non-positive value');
        }
      }
    }
  });

  test('every offered option leads to at least one product', () async {
    for (final categoryId in categoryIds) {
      final families = await facets.facetValues(
        facet: 'family',
        filter: ProductFilter(categoryId: categoryId),
      );

      for (final family in families) {
        final matches = await catalog.count(
          filter: ProductFilter(categoryId: categoryId, familyId: family.value),
        );
        expect(matches, family.matchCount);
        expect(matches, greaterThan(0));
      }
    }
  });

  test('facet values are scoped to their category', () async {
    final first = await facets.facetValues(
      facet: 'family',
      filter: ProductFilter(categoryId: categoryIds.first),
    );
    final last = await facets.facetValues(
      facet: 'family',
      filter: ProductFilter(categoryId: categoryIds.last),
    );

    final overlap = first
        .map((f) => f.value)
        .toSet()
        .intersection(last.map((f) => f.value).toSet());
    expect(overlap, isEmpty);
  });

  test('an unknown facet is rejected rather than interpolated into SQL', () {
    expect(
      () => db.catalogDao.distinctFacetValues(
        facet: 'name; DROP TABLE products',
        q: const ProductQuery(),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
