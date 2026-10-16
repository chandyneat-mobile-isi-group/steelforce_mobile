import 'dart:math';

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/mock/demo_api_errors.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/mock/isi_filter_schema_data.dart';
import 'package:steelforce/features/order/data/models/category_filter_schema_model.dart';
import 'package:steelforce/features/order/data/remote/material_selection_remote_data_source.dart';

/// `/api/v1/mobile/materials/*` for a demo build.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// In a demo the guided finder itself browses the device's synced catalog
/// (`ProductFilterRepositoryImpl`), so the selection reads here exist for
/// completeness. The read that matters is [fetchStock]: the SKU-step
/// availability check calls it whenever the demo is online, and it answers a
/// deterministic band per material from [DemoMaterialBook.stockFor].
class DemoMaterialSelectionRemoteDataSource
    implements MaterialSelectionRemoteDataSource {
  DemoMaterialSelectionRemoteDataSource(this._network, this._book);

  final DemoNetwork _network;
  final DemoMaterialBook _book;

  static const _plants = ['PP01', 'KD01'];

  /// Wire attribute (`ProductAttribute.wireName`) → the selection key it is
  /// answered under and the master-data field it reads.
  static final Map<String, (String, String Function(DemoMaterial))> _fields = {
    'Family': ('family', (m) => m.familyName),
    'Brand': ('brand', (m) => m.brand),
    'Colour': ('colour', (m) => m.colour),
    'Profile': ('profile', (m) => m.profile),
    'Grade': ('grade', (m) => m.grade),
    'Thickness': ('thickness', (m) => _num(m.thickness)),
    'Width': ('width', (m) => _num(m.width)),
    'Sku': ('materialNumber', (m) => m.number),
  };

  @override
  Future<List<DataMap>> fetchCategories({bool includeBlocked = false}) async {
    await _network.roundTrip();
    final materials = DemoMaterialBook.isiMaterials;
    return [
      for (final c in IsiDemoCatalog.categories())
        {
          'code': c['id'],
          'name': c['name'],
          'materialCount':
              materials.where((m) => m.categoryId == c['id']).length,
          'hasPublishedSchema': true,
        },
    ];
  }

  @override
  Future<List<CategoryFilterSchemaModel>> fetchSchemas(
      {String? categoryCode}) async {
    await _network.roundTrip();
    return IsiFilterSchemaData.schemas()
        .map(CategoryFilterSchemaModel.fromJson)
        .where((s) =>
            categoryCode == null ||
            categoryCode.isEmpty ||
            s.categoryId == categoryCode)
        .toList();
  }

  @override
  Future<List<DataMap>> fetchFacetOptions({
    required String attribute,
    required Map<String, dynamic> selection,
  }) async {
    await _network.roundTrip();
    final field = _fields[attribute];
    if (field == null) {
      throw DemoApiErrors.of(400, 'Material.UnknownFilterAttribute');
    }
    final counts = <String, int>{};
    for (final m in _matching(selection, except: field.$1)) {
      final value = field.$2(m);
      if (value.isEmpty || value == '0') continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return [
      for (final e in counts.entries)
        {'value': e.key, 'label': e.key, 'matchCount': e.value},
    ];
  }

  @override
  Future<MaterialPage> fetchMaterials({
    required Map<String, dynamic> selection,
    required int page,
    required int pageSize,
    String? search,
  }) async {
    await _network.roundTrip();
    final term = search?.trim().toLowerCase() ?? '';
    final answered = _fields.values.any((f) => selection[f.$1] != null);
    if (!answered && term.length < 2) {
      throw DemoApiErrors.of(400, 'Material.SelectionNotBounded');
    }
    final rows = _matching(selection)
        .where((m) =>
            term.isEmpty ||
            m.number.contains(term) ||
            m.description.toLowerCase().contains(term) ||
            m.descriptionKh.contains(term))
        .toList();
    final size = pageSize.clamp(1, 200);
    final start = (max(page, 1) - 1) * size;
    final slice = rows.skip(start).take(size).map(_row).toList();
    return MaterialPage(
      rows: slice,
      hasMore: start + size < rows.length,
      totalRecords: rows.length,
    );
  }

  @override
  Future<DataMap> fetchStock(String material) async {
    await _network.roundTrip();
    final known = await _book.lookup(material);
    if (known == null) throw DemoApiErrors.materialNotFound();
    final stock = DemoMaterialBook.stockFor(known.number);
    return {
      'material': known.number,
      'band': stock.band,
      'isSellable': stock.isSellable,
      'baseUnit': known.unit,
      'plants': [
        {
          'plant': _plants.first,
          'band': stock.band,
          'isSellable': stock.isSellable,
        },
        // The second plant holds a little of everything sellable, so the
        // tooltip shows a breakdown rather than a single row.
        {
          'plant': _plants.last,
          'band': stock.isSellable ? 'Low' : 'None',
          'isSellable': stock.isSellable,
        },
      ],
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<DataMap> fetchAvailability(
    String material, {
    String? salesOrg,
    String? disChannel,
    String? division,
    String? plant,
  }) async {
    await _network.roundTrip();
    final known = await _book.lookup(material);
    if (known == null) throw DemoApiErrors.materialNotFound();
    final sellable = DemoMaterialBook.stockFor(known.number).isSellable;
    return {
      'material': known.number,
      'isSellable': sellable,
      'summary': sellable ? 'Sellable' : 'No stock available',
      'checks': [
        {
          'sequence': '1',
          'checkId': 'STOCK',
          'status': sellable ? 'PASS' : 'FAIL',
          'message': sellable ? 'Stock available' : 'No stock available',
          'isVerdict': true,
        },
      ],
    };
  }

  Iterable<DemoMaterial> _matching(Map<String, dynamic> selection,
      {String? except}) {
    final category = selection['categoryCode'] as String?;
    return DemoMaterialBook.isiMaterials.where((m) {
      if (category != null && category.isNotEmpty && m.categoryId != category) {
        return false;
      }
      for (final field in _fields.values) {
        final wanted = selection[field.$1];
        if (wanted == null || field.$1 == except) continue;
        final value = wanted is num ? _num(wanted.toDouble()) : '$wanted';
        if (field.$2(m) != value) return false;
      }
      return true;
    });
  }

  static DataMap _row(DemoMaterial m) => {
        'id': m.number,
        'material': m.number,
        'materialName': m.description,
        'materialKhName': m.descriptionKh,
        'materialGroup': m.familyId,
        'materialGroupName': m.familyName,
        'materialGroupCategory': m.categoryId,
        'brand': m.brand,
        'grade': m.grade,
        'topColor': m.colour,
        'profile': m.profile,
        'saleThicknessMm': m.thickness,
        'widthMm': m.width,
        'netWeight': m.weight,
        'baseUnit': m.unit,
        'isBlocked': false,
      };

  /// Invariant numeric text, as the wire sends it: `0.3`, `1200`.
  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
