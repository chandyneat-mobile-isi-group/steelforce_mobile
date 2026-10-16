import 'dart:convert';

import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/data_domain.dart'
    show CustomizationMeasurement;
import 'package:steelforce/features/order/domain/entities/product.dart';

/// One editable dimension of a product customization. `appearance` is a free
/// text finish/coating/colour; the rest are numeric millimetre inputs.
enum CustomizationField {
  length,
  width,
  height,
  thickness,
  diameter,
  appearance,
}

/// Decides **which** customization inputs a product exposes, based on its
/// category — mirroring the catalog filter's category→facet logic
/// (`ProductFilterFacets.facetsFor`) so the two never drift apart. A pipe is
/// customized by diameter/thickness/length, a flat bar by thickness/width/
/// length, and so on; every category can also override its surface appearance.
///
/// Also owns the JSON codec for a customized [CartItem] so the cart and
/// quotation repositories serialize it identically.
class ProductCustomizationSpec {
  const ProductCustomizationSpec._();

  /// The customization fields for [product], in a stable display order
  /// (numeric dimensions first, `appearance` last).
  static List<CustomizationField> fieldsFor(Product product) {
    final name = '${product.subCategory} ${product.familyName} ${product.name}'
        .toLowerCase();

    final Set<CustomizationField> selected;
    if (name.contains('pipe') || name.contains('tube')) {
      selected = {
        CustomizationField.diameter,
        CustomizationField.thickness,
        CustomizationField.length,
      };
    } else if (name.contains('flat') ||
        name.contains('sheet') ||
        name.contains('plate')) {
      selected = {
        CustomizationField.thickness,
        CustomizationField.width,
        CustomizationField.length,
      };
    } else if (name.contains('structural') ||
        name.contains('beam') ||
        name.contains('angle') ||
        name.contains('channel')) {
      selected = {
        CustomizationField.length,
        CustomizationField.width,
        CustomizationField.height,
      };
    } else if (name.contains('hardware') || name.contains('accessor')) {
      selected = {CustomizationField.length};
    } else if (name.contains('wire') || name.contains('mesh')) {
      selected = {CustomizationField.length, CustomizationField.width};
    } else {
      // Rebar / generic steel → length + diameter.
      selected = {CustomizationField.length, CustomizationField.diameter};
    }
    // Every category can override appearance/finish.
    selected.add(CustomizationField.appearance);

    return CustomizationField.values.where(selected.contains).toList();
  }

  /// The base product's value for [field] in millimetres, used to prefill the
  /// form so the user tweaks a real starting spec. Returns null when the base
  /// product carries no meaningful value. [Product.length] is stored in metres;
  /// every other dimension is already in millimetres.
  static double? prefillMm(Product product, CustomizationField field) {
    double? nonZero(double v) => v > 0 ? v : null;
    return switch (field) {
      CustomizationField.length => nonZero(product.length * 1000),
      CustomizationField.width => nonZero(product.width),
      CustomizationField.height => nonZero(product.height),
      CustomizationField.thickness => nonZero(product.thickness),
      CustomizationField.diameter => nonZero(product.diameter),
      CustomizationField.appearance => null,
    };
  }

  static double? measurementValue(
      CustomizationMeasurement m, CustomizationField field) {
    return switch (field) {
      CustomizationField.length => m.lengthMm,
      CustomizationField.width => m.widthMm,
      CustomizationField.height => m.heightMm,
      CustomizationField.thickness => m.thicknessMm,
      CustomizationField.diameter => m.diameterMm,
      CustomizationField.appearance => null,
    };
  }

  static CustomizationMeasurement withField(
      CustomizationMeasurement m, CustomizationField field, double? value) {
    return switch (field) {
      CustomizationField.length => m.copyWith(lengthMm: value),
      CustomizationField.width => m.copyWith(widthMm: value),
      CustomizationField.height => m.copyWith(heightMm: value),
      CustomizationField.thickness => m.copyWith(thicknessMm: value),
      CustomizationField.diameter => m.copyWith(diameterMm: value),
      CustomizationField.appearance => m,
    };
  }

  // ── JSON codec (shared by cart + quotation persistence) ───────────────

  /// Encodes the customization portion of [item] to a JSON string, or null for
  /// a plain (non-customized) line so the DB column stays empty.
  static String? encode(CartItem item) {
    if (!item.isCustomized) return null;
    return jsonEncode({
      'appearance': item.appearance,
      'notes': item.customizationDescription,
      'drawing': item.drawingImagePath,
      'measurements': item.measurements?.toJson(),
    });
  }

  /// Returns a copy of [base] with the customization fields decoded from
  /// [json]. A null/empty [json] leaves [base] as a plain line.
  static CartItem applyEncoded(CartItem base, String? json) {
    if (json == null || json.isEmpty) return base;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final rawMeasure = map['measurements'] as Map<String, dynamic>?;
      return base.copyWith(
        isCustomized: true,
        appearance: map['appearance'] as String?,
        customizationDescription: map['notes'] as String?,
        drawingImagePath: map['drawing'] as String?,
        measurements: rawMeasure == null
            ? null
            : CustomizationMeasurement.fromJson(rawMeasure),
      );
    } catch (_) {
      // Malformed customization payload → fall back to the plain line rather
      // than dropping the whole cart/quotation row.
      return base;
    }
  }
}
