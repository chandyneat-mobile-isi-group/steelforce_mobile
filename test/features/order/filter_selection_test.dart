import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/domain/entities/filter/category_filter_schema.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/entities/filter/product_attribute.dart';

const _family = FilterStep(
  key: 'family',
  label: 'Product Family',
  attribute: ProductAttribute.family,
  sortOrder: 0,
  role: FilterStepRole.family,
);
const _thickness = FilterStep(
  key: 'thickness',
  label: 'Thickness',
  attribute: ProductAttribute.thickness,
  sortOrder: 1,
);
const _length = FilterStep(
  key: 'length',
  label: 'Length',
  attribute: ProductAttribute.length,
  sortOrder: 2,
);

const _schema = CategoryFilterSchema(
  categoryId: 'cat_isi_palm',
  categoryName: 'Palm',
  steps: [_family, _thickness, _length],
);

FilterOption _option(String value) =>
    FilterOption(value: value, label: value, matchCount: 3);

void main() {
  group('FilterSelection dependency rules', () {
    test('answers accumulate in step order', () {
      final selection = const FilterSelection.empty()
          .select(_family, _option('fam_palm_70'))
          .select(_thickness, _option('0.3'));

      expect(selection.entries.map((e) => e.stepKey), ['family', 'thickness']);
      expect(selection.valueFor('thickness'), '0.3');
    });

    test('re-answering a step invalidates every answer below it', () {
      final complete = const FilterSelection.empty()
          .select(_family, _option('fam_palm_70'))
          .select(_thickness, _option('0.3'))
          .select(_length, _option('3.9'));

      final rechosen = complete.select(_family, _option('fam_palm_100'));

      expect(rechosen.valueFor('family'), 'fam_palm_100');
      expect(rechosen.valueFor('thickness'), isNull,
          reason: 'a thickness the new family may not stock must not survive');
      expect(rechosen.valueFor('length'), isNull);
    });

    test('clearing a chip drops it and its dependents, keeping what is above',
        () {
      final complete = const FilterSelection.empty()
          .select(_family, _option('fam_palm_70'))
          .select(_thickness, _option('0.3'))
          .select(_length, _option('3.9'));

      final cleared = complete.clearFrom('thickness');

      expect(cleared.valueFor('family'), 'fam_palm_70');
      expect(cleared.valueFor('thickness'), isNull);
      expect(cleared.valueFor('length'), isNull);
    });

    test('clearing an unanswered step is a no-op', () {
      final selection =
          const FilterSelection.empty().select(_family, _option('fam'));
      expect(selection.clearFrom('length'), selection);
    });
  });

  group('FilterSelection completeness', () {
    test('nextStep walks the schema in order and ends at null', () {
      var selection = const FilterSelection.empty();
      expect(selection.nextStep(_schema), _family);
      expect(selection.isComplete(_schema), isFalse);

      selection = selection.select(_family, _option('fam'));
      expect(selection.nextStep(_schema), _thickness);

      selection = selection
          .select(_thickness, _option('0.3'))
          .select(_length, _option('3.9'));
      expect(selection.nextStep(_schema), isNull);
      expect(selection.isComplete(_schema), isTrue);
    });

    test('optional steps never block completeness', () {
      const optional = FilterStep(
        key: 'grade',
        label: 'Grade',
        attribute: ProductAttribute.grade,
        sortOrder: 1,
        isRequired: false,
      );
      const schema = CategoryFilterSchema(
        categoryId: 'c',
        categoryName: 'C',
        steps: [_family, optional],
      );

      final selection =
          const FilterSelection.empty().select(_family, _option('fam'));
      expect(selection.isComplete(schema), isTrue);
    });
  });

  group('FilterSelection.toProductFilter', () {
    test('maps every attribute onto the catalog query, parsing numerics', () {
      const brand = FilterStep(
        key: 'brand',
        label: 'Brand',
        attribute: ProductAttribute.brand,
        sortOrder: 3,
      );

      final filter = const FilterSelection.empty()
          .select(_family, _option('fam_palm_70'))
          .select(_thickness, _option('0.3'))
          .select(_length, _option('3.9'))
          .select(brand, _option('ISI Steel'))
          .toProductFilter('cat_isi_palm');

      expect(filter.categoryId, 'cat_isi_palm');
      expect(filter.familyId, 'fam_palm_70');
      expect(filter.thickness, 0.3);
      expect(filter.length, 3.9);
      expect(filter.brand, 'ISI Steel');
    });

    test('an empty selection narrows to the category alone', () {
      final filter = const FilterSelection.empty().toProductFilter('cat_x');
      expect(filter.categoryId, 'cat_x');
      expect(filter.hasActiveAttributes, isFalse);
      expect(filter.familyId, isNull);
    });
  });
}
