import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/database/drift/daos/catalog_dao.dart';
import 'package:steelforce/features/order/data/local/product_filter_local_data_source.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/models/category_filter_schema_model.dart';
import 'package:steelforce/features/order/data/remote/mock_product_filter_remote_data_source.dart';
import 'package:steelforce/features/order/data/remote/product_filter_remote_data_source.dart';
import 'package:steelforce/features/order/data/repositories/product_filter_repository_impl.dart';
import 'package:steelforce/features/order/domain/entities/filter/category_filter_schema.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/entities/filter/product_attribute.dart';
import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Records what was asked of the catalog so the tests can assert the
/// repository never reaches past the level it was asked for.
class _FakeLocal implements ProductFilterLocalDataSource {
  _FakeLocal({this.values = const []});

  List<CatalogFacetValue> values;
  final List<({String facet, ProductFilter filter})> calls = [];

  @override
  Future<List<CategoryModel>> categoriesWithProducts() async => const [
        CategoryModel(
          id: IsiDemoCatalog.palmProfileCategoryId,
          code: 'PALM_PROFILE',
          name: LocalizedText(en: 'Palm Profile Roofing', km: 'ផាម ភ្លី'),
          displayOrder: 0,
        ),
      ];

  @override
  Future<List<CatalogFacetValue>> facetValues({
    required String facet,
    required ProductFilter filter,
  }) async {
    calls.add((facet: facet, filter: filter));
    return values;
  }
}

class _StubRemote implements ProductFilterRemoteDataSource {
  _StubRemote(this.schemas);
  final List<CategoryFilterSchemaModel> schemas;
  int fetchCount = 0;

  @override
  Future<List<CategoryFilterSchemaModel>> fetchFilterSchemas() async {
    fetchCount++;
    return schemas;
  }
}

CatalogFacetValue _facet(String value, {String? label, int count = 4}) =>
    CatalogFacetValue(value: value, label: label ?? value, matchCount: count);

void main() {
  group('schema resolution', () {
    test('serves the published hierarchy for a known category', () async {
      final repository = ProductFilterRepositoryImpl(
        remote: MockProductFilterRemoteDataSource(),
        local: _FakeLocal(),
      );

      final result = await repository
          .getFilterSchema(IsiDemoCatalog.palmProfileCategoryId);
      final schema = result.when(success: (s) => s, failure: (_) => null);

      expect(schema, isNotNull);
      expect(schema!.steps.map((s) => s.key),
          ['profile', 'coating', 'gauge', 'colour']);
      // Sort order is assigned on the way in, so callers can consume `steps`
      // in order without re-sorting.
      expect(
        schema.steps.map((s) => s.sortOrder),
        List.generate(schema.steps.length, (i) => i),
      );
      expect(schema.stepByKey('profile')!.role, FilterStepRole.family);
      expect(schema.stepByKey('gauge')!.unitSuffix, 'mm');
      expect(schema.stepByKey('gauge')!.decimals, 2);
    });

    test('falls back to the generic hierarchy for an unpublished category',
        () async {
      final repository = ProductFilterRepositoryImpl(
        remote: MockProductFilterRemoteDataSource(),
        local: _FakeLocal(),
      );

      final result = await repository.getFilterSchema('cat_steel_rebar');
      final schema = result.when(success: (s) => s, failure: (_) => null);

      expect(schema, isNotNull);
      expect(schema!.isFlat, isFalse);
      expect(schema.requiredSteps, isEmpty,
          reason: 'generic steps are all optional so they can be skipped');
    });

    test('the schema document is fetched once and reused', () async {
      final remote = _StubRemote(const []);
      final repository =
          ProductFilterRepositoryImpl(remote: remote, local: _FakeLocal());

      await repository.getFilterSchema('a');
      await repository.getFilterSchema('b');

      expect(remote.fetchCount, 1);
    });
  });

  group('step options', () {
    const schema = CategoryFilterSchema(
      categoryId: IsiDemoCatalog.palmProfileCategoryId,
      categoryName: 'Palm',
      steps: [
        FilterStep(
          key: 'family',
          label: 'Family',
          attribute: ProductAttribute.family,
          sortOrder: 0,
          role: FilterStepRole.family,
        ),
        FilterStep(
          key: 'thickness',
          label: 'Thickness',
          attribute: ProductAttribute.thickness,
          sortOrder: 1,
          unitSuffix: 'mm',
          decimals: 2,
        ),
      ],
    );

    test('resolves one facet, narrowed by the answers above it', () async {
      final local = _FakeLocal(values: [_facet('0.3'), _facet('0.4')]);
      final repository = ProductFilterRepositoryImpl(
        remote: MockProductFilterRemoteDataSource(),
        local: local,
      );

      final selection = const FilterSelection.empty().select(
        schema.steps.first,
        const FilterOption(
            value: 'fam_palm_70', label: 'Palm 70', matchCount: 2),
      );

      await repository.getStepOptions(
        schema: schema,
        step: schema.steps[1],
        selection: selection,
      );

      expect(local.calls, hasLength(1));
      expect(local.calls.single.facet, 'thickness');
      expect(local.calls.single.filter.categoryId,
          IsiDemoCatalog.palmProfileCategoryId);
      expect(local.calls.single.filter.familyId, 'fam_palm_70');
    });

    test('applies the published notation to numeric labels', () async {
      final repository = ProductFilterRepositoryImpl(
        remote: MockProductFilterRemoteDataSource(),
        local: _FakeLocal(values: [_facet('0.3'), _facet('0.4')]),
      );

      final result = await repository.getStepOptions(
        schema: schema,
        step: schema.steps[1],
        selection: const FilterSelection.empty(),
      );
      final options = result.when(success: (o) => o, failure: (_) => null);

      expect(options!.map((o) => o.label), ['0.30 mm', '0.40 mm']);
      expect(options.map((o) => o.value), ['0.3', '0.4'],
          reason: 'the query value stays raw so it round-trips to SQL');
    });

    test('text facets pass through untouched', () async {
      final repository = ProductFilterRepositoryImpl(
        remote: MockProductFilterRemoteDataSource(),
        local: _FakeLocal(
            values: [_facet('fam_palm_70', label: 'Palm 70', count: 2)]),
      );

      final result = await repository.getStepOptions(
        schema: schema,
        step: schema.steps.first,
        selection: const FilterSelection.empty(),
      );
      final options = result.when(success: (o) => o, failure: (_) => null);

      expect(options!.single.value, 'fam_palm_70');
      expect(options.single.label, 'Palm 70');
      expect(options.single.matchCount, 2);
    });
  });
}
