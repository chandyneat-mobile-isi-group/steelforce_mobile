import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/filter/product_attribute.dart';

/// How a step's options should be presented. SAP-driven, because the right
/// control depends on the data shape, not on the screen: three profiles are
/// chips, twelve diameters are a grid, a family list wants rows with counts.
enum FilterStepStyle { chips, grid, list }

/// Semantic role of a step within its category's flow.
///
/// [family] and [sku] are special-cased in the UI — each gets its own richer
/// selector; [specification] and [dimension] render through the generic
/// dynamic selector.
///
/// Two of these carry an ordering invariant the server enforces at publish
/// time, so the client can rely on it rather than re-checking: a [family] step
/// is always first, and a [sku] step is always last.
enum FilterStepRole {
  family,
  specification,
  dimension,

  /// The material leaf — the exact SAP material number.
  ///
  /// Always the final step, conventionally published at `sortOrder: 99`. It
  /// exists because after every attribute is answered, several genuinely
  /// different material numbers can still match: the live master returns four
  /// for `FG-RF / CAP 980PU / PALM 100PPGL / 0.40 mm / Brick Red`, differing in
  /// a PU core depth and a backing sheet that SAP holds but publishes on no
  /// attribute column. Picking one of four look-alike rows by eye is the guess
  /// this step removes.
  sku,
}

/// One level of a category's filter hierarchy, as defined by SAP.
///
/// Steps are ordered by [sortOrder] and consumed strictly in order: a step's
/// options are always resolved against every selection made *above* it, which
/// is what keeps the flow progressive (one small query per level) and free of
/// dead ends (an option that matches nothing is never offered).
class FilterStep extends Equatable {
  const FilterStep({
    required this.key,
    required this.label,
    required this.attribute,
    required this.sortOrder,
    this.style = FilterStepStyle.chips,
    this.role = FilterStepRole.specification,
    this.unitSuffix,
    this.decimals,
    this.isRequired = true,
  });

  /// Stable identifier used as the selection map key and in analytics — never
  /// shown to the user.
  final String key;

  /// Business label as SAP defines it ("Profile", "Shape", "Colour", …).
  final String label;

  final ProductAttribute attribute;
  final int sortOrder;
  final FilterStepStyle style;
  final FilterStepRole role;

  /// Appended to numeric option labels ("0.30" → "0.30 mm").
  final String? unitSuffix;

  /// Fixed decimal places for numeric option labels. SAP-published because the
  /// convention is per-attribute business notation, not a rendering
  /// preference: coil thickness reads "0.30", rebar diameter reads "12".
  /// Null falls back to the value's natural precision.
  final int? decimals;

  /// Optional steps can be skipped without blocking the product query.
  final bool isRequired;

  @override
  List<Object?> get props => [
        key,
        label,
        attribute,
        sortOrder,
        style,
        role,
        unitSuffix,
        decimals,
        isRequired,
      ];
}
