import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// A single attribute filter dimension. Declared in the spec's canonical
/// order (Size → Length → Mesh Size → Quality …); [ProductFilterFacets.facetsFor]
/// decides which subset a given category exposes, but the enum order is what
/// the UI renders in — so "the order never changes".
enum FilterFacet {
  size,
  length,
  meshSize,
  quality,
  diameter,
  thickness,
  material
}

extension FilterFacetLabel on FilterFacet {
  String get label => switch (this) {
        FilterFacet.size => 'orders.filter.size'.tr,
        FilterFacet.length => 'orders.filter.length'.tr,
        FilterFacet.meshSize => 'orders.filter.mesh_size'.tr,
        FilterFacet.quality => 'orders.filter.quality'.tr,
        FilterFacet.diameter => 'orders.filter.diameter'.tr,
        FilterFacet.thickness => 'orders.filter.thickness'.tr,
        FilterFacet.material => 'orders.filter.material'.tr,
      };
}

/// Pure mapping layer between the [Product] catalog data, the [ProductFilter]
/// entity, and the display strings the filter UI shows. Centralised here so
/// the ProductFilterScreen and the quotation builder never re-implement (and
/// drift on) option formatting / parsing.
class ProductFilterFacets {
  const ProductFilterFacets._();

  /// Which facets a top-level category exposes, in canonical enum order.
  /// [categoryName] is the top-level category's display name (or null for
  /// "All"). Category-dependent per the spec (Pipe → diameter/thickness/…,
  /// Flat → thickness/length/quality, etc.).
  static List<FilterFacet> facetsFor(String? categoryName) {
    final name = (categoryName ?? '').toLowerCase();
    final Set<FilterFacet> selected;
    if (name.contains('pipe')) {
      selected = {
        FilterFacet.diameter,
        FilterFacet.thickness,
        FilterFacet.length,
        FilterFacet.material,
      };
    } else if (name.contains('flat')) {
      selected = {
        FilterFacet.thickness,
        FilterFacet.length,
        FilterFacet.quality
      };
    } else if (name.contains('structural')) {
      selected = {FilterFacet.size, FilterFacet.length, FilterFacet.quality};
    } else if (name.contains('hardware') || name.contains('accessor')) {
      selected = {FilterFacet.size, FilterFacet.material};
    } else if (name.contains('wire') || name.contains('mesh')) {
      selected = {FilterFacet.size, FilterFacet.meshSize, FilterFacet.quality};
    } else {
      // Steel / Rebar / All / anything else → the core three.
      selected = {FilterFacet.size, FilterFacet.length, FilterFacet.quality};
    }
    return FilterFacet.values.where(selected.contains).toList();
  }

  /// Distinct, sorted, display-formatted option values for [facet] derived
  /// from the currently loaded [items].
  static List<String> optionsFor(FilterFacet facet, List<Product> items) {
    switch (facet) {
      case FilterFacet.size:
        return _distinctStrings(items.map((p) => p.size));
      case FilterFacet.quality:
        return _distinctStrings(items.map((p) => p.grade));
      case FilterFacet.material:
        return _distinctStrings(items.map((p) => p.material));
      case FilterFacet.length:
        return _distinctNumbers(items.map((p) => p.length), _formatLength);
      case FilterFacet.diameter:
        return _distinctNumbers(items.map((p) => p.diameter), _formatMm);
      case FilterFacet.thickness:
        return _distinctNumbers(items.map((p) => p.thickness), _formatMm);
      case FilterFacet.meshSize:
        final values = items
            .where((p) => p.width > 0 && p.height > 0)
            .map((p) => _formatMesh(p.width, p.height))
            .toSet()
            .toList()
          ..sort();
        return values;
    }
  }

  /// The currently selected display value of [facet] within [filter], or null.
  static String? selectedValue(FilterFacet facet, ProductFilter filter) {
    switch (facet) {
      case FilterFacet.size:
        return filter.size;
      case FilterFacet.quality:
        return filter.grade;
      case FilterFacet.material:
        return filter.material;
      case FilterFacet.length:
        return filter.length == null ? null : _formatLength(filter.length!);
      case FilterFacet.diameter:
        return filter.diameter == null ? null : _formatMm(filter.diameter!);
      case FilterFacet.thickness:
        return filter.thickness == null ? null : _formatMm(filter.thickness!);
      case FilterFacet.meshSize:
        return (filter.width != null && filter.height != null)
            ? _formatMesh(filter.width!, filter.height!)
            : null;
    }
  }

  /// Returns a copy of [filter] with [facet] set to [value] (a display string
  /// as produced by [optionsFor]) or cleared when [value] is null.
  static ProductFilter apply(
      FilterFacet facet, String? value, ProductFilter filter) {
    switch (facet) {
      case FilterFacet.size:
        return filter.copyWith(size: () => value);
      case FilterFacet.quality:
        return filter.copyWith(grade: () => value);
      case FilterFacet.material:
        return filter.copyWith(material: () => value);
      case FilterFacet.length:
        return filter.copyWith(length: () => _parseNumber(value));
      case FilterFacet.diameter:
        return filter.copyWith(diameter: () => _parseNumber(value));
      case FilterFacet.thickness:
        return filter.copyWith(thickness: () => _parseNumber(value));
      case FilterFacet.meshSize:
        final dims = _parseMesh(value);
        return filter.copyWith(
          width: () => dims?.$1,
          height: () => dims?.$2,
        );
    }
  }

  /// Short "Label: value" summary for the active-filter chips, or null when
  /// the facet is inactive.
  static String? chipLabel(FilterFacet facet, ProductFilter filter) {
    final value = selectedValue(facet, filter);
    return value == null ? null : '${facet.label}: $value';
  }

  // ── Formatting / parsing ──────────────────────────────────────────────
  static String _formatNumber(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  static String _formatLength(double v) => '${_formatNumber(v)} m';
  static String _formatMm(double v) => '${_formatNumber(v)} mm';
  static String _formatMesh(double w, double h) =>
      '${_formatNumber(w)}x${_formatNumber(h)} mm';

  /// Parses the leading number out of a display string ("12 m" → 12.0).
  static double? _parseNumber(String? display) {
    if (display == null) return null;
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(display);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  static (double, double)? _parseMesh(String? display) {
    if (display == null) return null;
    final parts = display.replaceAll(RegExp('[a-zA-Z]'), '').trim().split('x');
    if (parts.length != 2) return null;
    final w = double.tryParse(parts[0].trim());
    final h = double.tryParse(parts[1].trim());
    return (w == null || h == null) ? null : (w, h);
  }

  static List<String> _distinctStrings(Iterable<String> values) =>
      (values.where((s) => s.trim().isNotEmpty).toSet().toList())..sort();

  static List<String> _distinctNumbers(
      Iterable<double> values, String Function(double) format) {
    final distinct = values.where((v) => v > 0).toSet().toList()..sort();
    return distinct.map(format).toList();
  }
}
