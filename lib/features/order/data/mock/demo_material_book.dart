import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';

/// One material as the demo backend knows it: master data, list price, stock.
class DemoMaterial {
  const DemoMaterial({
    required this.number,
    required this.description,
    required this.descriptionKh,
    required this.unit,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    this.familyId = '',
    this.familyName = '',
    this.brand = '',
    this.grade = '',
    this.colour = '',
    this.profile = '',
    this.thickness = 0,
    this.width = 0,
    this.weight = 0,
  });

  final String number;
  final String description;
  final String descriptionKh;

  /// The price's condition unit, and the material's base unit.
  final String unit;

  /// List price per [unit], in USD.
  final double price;
  final String categoryId;
  final String categoryName;
  final String familyId;
  final String familyName;
  final String brand;
  final String grade;
  final String colour;
  final String profile;
  final double thickness;
  final double width;
  final double weight;
}

/// The stock band the demo backend answers for one material.
class DemoStock {
  const DemoStock({required this.band, required this.isSellable});
  final String band;
  final bool isSellable;
}

/// The demo backend's material master and price list.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// One book feeds pricing, stock and quotation lines, so a material's price on
/// the finder card, on the quotation line and in its totals is the same number.
/// The 60 hand-written ISI lines ([IsiDemoCatalog]) answer instantly and
/// deterministically; any other material — the bulk generated catalog — is
/// looked up in the device's synced catalog, so its price agrees with what the
/// rep was browsing rather than with an invented figure.
class DemoMaterialBook {
  DemoMaterialBook({ProductLocalDataSource? catalog}) : _catalog = catalog;

  final ProductLocalDataSource? _catalog;

  static final Map<String, DemoMaterial> _isi = _buildIsi();

  /// The hand-written ISI lines, in catalog order. Seeded quotations draw from
  /// these, so their prices never depend on what the device has synced.
  static List<DemoMaterial> get isiMaterials => _isi.values.toList();

  static DemoMaterial isi(String number) => _isi[number]!;

  Future<DemoMaterial?> lookup(String number) async {
    final key = number.trim();
    if (key.isEmpty) return null;
    final known = _isi[key];
    if (known != null) return known;
    return _fromCatalog(key);
  }

  /// Deterministic per material, so a demo shows the same badge every run:
  /// about one material in twelve is out of stock, the rest spread across
  /// High / Medium / Low.
  static DemoStock stockFor(String number) {
    final hash = number.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) % 9973);
    return switch (hash % 12) {
      0 => const DemoStock(band: 'None', isSellable: false),
      1 || 2 => const DemoStock(band: 'Low', isSellable: true),
      3 || 4 || 5 || 6 => const DemoStock(band: 'Medium', isSellable: true),
      _ => const DemoStock(band: 'High', isSellable: true),
    };
  }

  Future<DemoMaterial?> _fromCatalog(String number) async {
    final catalog = _catalog;
    if (catalog == null) return null;
    final rows = await catalog.browse(page: 0, pageSize: 10, query: number);
    for (final row in rows) {
      if (row.materialCode == number) return _fromProduct(row);
    }
    return null;
  }

  static DemoMaterial _fromProduct(ProductModel p) => DemoMaterial(
        number: p.materialCode,
        description: p.name,
        descriptionKh: p.nameKh,
        unit: p.unit,
        price: p.pricing.standardPrice,
        categoryId: p.categoryId,
        categoryName: p.categoryId,
        familyId: p.familyId,
        familyName: p.familyName,
        brand: p.brand,
        grade: p.grade,
        colour: p.subCategory,
        profile: p.size,
        thickness: p.thickness,
        width: p.width,
        weight: p.weight,
      );

  static Map<String, DemoMaterial> _buildIsi() {
    final names = {
      for (final c in IsiDemoCatalog.categories())
        c['id'] as String: c['name'] as String,
    };
    return {
      for (final p in IsiDemoCatalog.products())
        p['materialCode'] as String: DemoMaterial(
          number: p['materialCode'] as String,
          description: p['name'] as String,
          descriptionKh: p['nameKh'] as String,
          unit: p['unit'] as String,
          price: ((p['pricing'] as Map)['standardPrice'] as num).toDouble(),
          categoryId: p['categoryId'] as String,
          categoryName: names[p['categoryId']] ?? p['categoryId'] as String,
          familyId: p['familyId'] as String,
          familyName: p['familyName'] as String,
          brand: p['brand'] as String,
          grade: p['grade'] as String,
          colour: p['subCategory'] as String,
          profile: p['size'] as String,
          thickness: (p['thickness'] as num).toDouble(),
          width: (p['width'] as num).toDouble(),
          weight: (p['weight'] as num).toDouble(),
        ),
    };
  }
}
