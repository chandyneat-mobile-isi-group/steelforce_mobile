import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart' hide Category;
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/order/data/local/product_drift_local_data_source.dart';
import 'package:steelforce/features/order/data/local/product_drift_mappers.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/mock/mock_product_data.dart';
import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Guards the single-source localisation contract.
///
/// The bug these exist to prevent already shipped once: the widgets were
/// correctly locale-aware, the entity correctly carried both languages — and
/// the *data* had no Khmer at all, so `LocalizedText.resolve` fell back and
/// every category rendered in English inside a Khmer UI. Nothing failed; it
/// just quietly looked untranslated.
///
/// So these assert the whole chain, not the pieces: master data carries Khmer,
/// it survives the trip through Drift, and it comes back out under `km`.
void main() {
  group('master data carries both languages', () {
    test('every ISI category has a Khmer name distinct from English', () {
      for (final row in IsiDemoCatalog.categories()) {
        final km = (row['nameKh'] as String?) ?? '';
        expect(km.trim(), isNotEmpty,
            reason: '${row['name']} has no Khmer name — it will silently '
                'render in English inside a Khmer UI');
        expect(km, isNot(row['name']),
            reason: '${row['name']} has English text in its Khmer field');
      }
    });

    test('every traded category has a Khmer name distinct from English', () {
      for (final row in CategoryGenerator.categories) {
        final km = (row['nameKh'] as String?) ?? '';
        expect(km.trim(), isNotEmpty, reason: '${row['name']} has no Khmer');
        expect(km, isNot(row['name']));
      }
    });

    test('every ISI demo product carries a Khmer name', () {
      for (final row in IsiDemoCatalog.products()) {
        final km = (row['nameKh'] as String?) ?? '';
        expect(km.trim(), isNotEmpty,
            reason: '${row['code']} has no Khmer material description');
      }
    });

    test('Khmer names actually contain Khmer script', () {
      // Catches the copy-paste failure where the Khmer column gets filled with
      // a transliteration or the English string again.
      bool hasKhmer(String s) => s.runes.any((r) => r >= 0x1780 && r <= 0x17FF);

      for (final row in IsiDemoCatalog.categories()) {
        expect(hasKhmer(row['nameKh'] as String), isTrue,
            reason: '${row['name']}: Khmer field has no Khmer characters');
      }
    });
  });

  group('LocalizedText resolution', () {
    test('resolves per language', () {
      const text = LocalizedText(en: 'Galvanized Pipes', km: 'បំពង់ស័ង្កសី');
      expect(text.resolve('en'), 'Galvanized Pipes');
      expect(text.resolve('km'), 'បំពង់ស័ង្កសី');
    });

    test('falls back to English when Khmer is missing', () {
      // Real SAP rows do lack MaterialDesKH. Falling back beats a blank label:
      // a rep who cannot read the English can still match the code beside it.
      const text = LocalizedText(en: 'Steel Plate', km: '');
      expect(text.resolve('km'), 'Steel Plate');
    });

    test('falls back to Khmer when English is missing', () {
      const text = LocalizedText(en: '', km: 'ផ្ទាំងដែក');
      expect(text.resolve('en'), 'ផ្ទាំងដែក');
    });

    test('an unknown locale gets English', () {
      const text = LocalizedText(en: 'Cable', km: 'ខ្សែភ្លើង');
      expect(text.resolve('fr'), 'Cable');
    });

    test('search values span both languages', () {
      const text = LocalizedText(en: 'K-Pipe', km: 'បំពង់ K');
      expect(text.allValues, containsAll(['K-Pipe', 'បំពង់ K']));
    });
  });

  group('Khmer survives the round trip through Drift', () {
    late AppDatabase db;
    late ProductDriftLocalDataSource catalog;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      catalog = ProductDriftLocalDataSource(db.catalogDao);
    });
    tearDown(() => db.close());

    test('categories keep both names across write and read', () async {
      await catalog.upsertCategories(
        IsiDemoCatalog.categories().map(CategoryModel.fromJson).toList(),
      );

      final rows = await db.catalogDao.fetchCategories();
      expect(rows, isNotEmpty);

      for (final row in rows.map((r) => r.toModel())) {
        expect(row.name.km.trim(), isNotEmpty,
            reason: '${row.name.en} lost its Khmer in the database — this is '
                'exactly where it went missing before');
        expect(row.name.resolve('km'), row.name.km);
        expect(row.name.resolve('en'), row.name.en);
        expect(row.code.trim(), isNotEmpty);
      }
    });

    test('products keep their Khmer name across write and read', () async {
      await catalog.upsertProducts(
        IsiDemoCatalog.products().map(ProductModel.fromJson).toList(),
      );

      final rows = await catalog.browse(page: 0, pageSize: 100);
      expect(rows, isNotEmpty);

      for (final product in rows) {
        expect(product.nameKh.trim(), isNotEmpty,
            reason: '${product.code} lost its Khmer name');
        expect(product.displayName.resolve('km'), product.nameKh);
      }
    });

    test('a Khmer search term finds its product', () async {
      await catalog.upsertProducts(
        IsiDemoCatalog.products().map(ProductModel.fromJson).toList(),
      );

      // A distinctive Khmer word taken from the data itself, so this tracks
      // the extract rather than a literal that goes stale.
      final sample = IsiDemoCatalog.products().first['nameKh'] as String;
      final term = sample.split(RegExp(r'\s+')).first;

      final hits = await catalog.browse(page: 0, pageSize: 50, query: term);

      expect(hits, isNotEmpty,
          reason: 'searching "$term" returned nothing — Khmer text is in the '
              'database but not in the search columns');
      expect(hits.every((p) => p.nameKh.contains(term)), isTrue);
    });

    test('an English search still works with Khmer data present', () async {
      await catalog.upsertProducts(
        IsiDemoCatalog.products().map(ProductModel.fromJson).toList(),
      );

      final hits = await catalog.browse(page: 0, pageSize: 50, query: 'TRIM');

      expect(hits, isNotEmpty);
      expect(
        hits.every((p) =>
            p.name.toUpperCase().contains('TRIM') ||
            p.code.toUpperCase().contains('TRIM') ||
            p.size.toUpperCase().contains('TRIM')),
        isTrue,
      );
    });

    test('colour and specification reach the database', () async {
      await catalog.upsertProducts(
        IsiDemoCatalog.products().map(ProductModel.fromJson).toList(),
      );

      final rows = await catalog.browse(
        page: 0,
        pageSize: 10,
        filter: const ProductFilter(
            categoryId: IsiDemoCatalog.palmProfileCategoryId),
      );

      expect(rows, isNotEmpty);
      for (final product in rows) {
        expect(product.color.trim(), isNotEmpty);
        expect(product.specification.trim(), isNotEmpty);
      }
    });
  });
}
