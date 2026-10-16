/// The catalog column a dynamic filter step narrows on.
///
/// This is the *only* hardcoded thing in the guided filter flow, and it has to
/// be: it's the closed set of attributes the material master physically
/// carries. SAP decides which of them a category exposes, in what order, and
/// under what business label ("Profile", "Coating Line", "Colour" all land on
/// real columns) — the app never decides that. Adding a genuinely new attribute
/// is a schema change on both sides, not a configuration change, which is
/// exactly why it lives in code.
///
/// ## Two vocabularies, one enum
///
/// The members below span **both** data sources the flow can run against:
///
///  * the platform's material selection API, whose `MaterialFilterField` enum
///    this mirrors ([wireName] is the exact string it sends and expects); and
///  * the device's local Drift catalog, whose columns the offline path groups
///    on.
///
/// They overlap but do not coincide, and pretending otherwise is how a step
/// silently narrows nothing. [isServerField] and [localFacet] say which is
/// which, per `docs/features/material-mobile-selection/business-logic.md`:
///
///  * SAP's material master has **no plant column**, so [warehouse] exists only
///    on the local path. There is no stock-location facet against the API.
///  * SAP does not return length, height, diameter or substance, so [length],
///    [height], [diameter] and [material] are local-only too.
///  * [materialType], [division], [priceGroup] and [rawThickness] are SAP
///    classifications the local catalog has no column for.
enum ProductAttribute {
  family,

  /// The plant/warehouse holding the stock — `products.warehouse_code`.
  ///
  /// **Local path only.** SAP's material master returns one row per material
  /// with no plant column; where a material is stocked is a separate
  /// per-material question (`/availability`), not an aggregate the material
  /// table can group on. Publishing it as a facet would mean returning match
  /// counts nothing can honestly compute.
  warehouse,

  subCategory,
  brand,

  /// SAP `TopColor`. The local catalog loads the same value into
  /// `sub_category`, which is why [localFacet] maps the two together.
  colour,

  /// SAP `Profile` — the catalogue size dimension for roofing and sections.
  /// Carries what a size code would elsewhere, so it maps onto the local
  /// `size` column.
  profile,

  size,
  grade,
  material,
  length,
  width,
  height,
  diameter,

  /// SAP `SaleThicknessMm` — **what you quote to a depot**. Never
  /// [rawThickness], which is the coil it was rolled from.
  thickness,

  /// SAP `RawThicknessMm`. Published as a filterable field, but it is not the
  /// number that goes on a quotation.
  rawThickness,

  materialType,
  division,

  /// SAP's pricing *classification* (`A7` / `TRIM_PALM100PP`) — a bucket for
  /// condition lookup. It carries no amount, no currency and no depot.
  /// Filterable; never renderable as a price.
  priceGroup,

  /// The material itself — the leaf of every hierarchy.
  ///
  /// After every attribute is answered several genuinely different material
  /// numbers can still match, differing in something SAP holds but publishes on
  /// no attribute column. Making the material an explicit, counted step is what
  /// ends the guess before a quantity is typed.
  sku;

  /// Numeric attributes round-trip through `double`; the rest are text.
  bool get isNumeric => switch (this) {
        ProductAttribute.length ||
        ProductAttribute.width ||
        ProductAttribute.height ||
        ProductAttribute.diameter ||
        ProductAttribute.thickness ||
        ProductAttribute.rawThickness =>
          true,
        _ => false,
      };

  /// The exact string the selection API uses for this field, both as the
  /// `attribute` on a facet request and as the enum member the schema
  /// publishes. Null for the members the material master has no column for —
  /// a step naming one of those can only come from the local path.
  ///
  /// Case matters on the way *out* (the server is given what it published) but
  /// not on the way in — [tryParse] is case-insensitive, so `Thickness` and
  /// `thickness` both resolve.
  String? get wireName => switch (this) {
        ProductAttribute.family => 'Family',
        ProductAttribute.brand => 'Brand',
        ProductAttribute.colour => 'Colour',
        ProductAttribute.subCategory => 'Colour',
        ProductAttribute.profile => 'Profile',
        ProductAttribute.size => 'Profile',
        ProductAttribute.grade => 'Grade',
        ProductAttribute.thickness => 'Thickness',
        ProductAttribute.rawThickness => 'RawThickness',
        ProductAttribute.width => 'Width',
        ProductAttribute.materialType => 'MaterialType',
        ProductAttribute.division => 'Division',
        ProductAttribute.priceGroup => 'PriceGroup',
        ProductAttribute.sku => 'Sku',
        ProductAttribute.warehouse ||
        ProductAttribute.material ||
        ProductAttribute.length ||
        ProductAttribute.height ||
        ProductAttribute.diameter =>
          null,
      };

  /// The key this answer takes inside the API's flat `selection` object.
  ///
  /// Not derivable from [wireName]: the `Sku` attribute is answered as
  /// `materialNumber`, because the selection object names the *value* while the
  /// facet request names the *field*.
  String? get selectionKey => switch (this) {
        ProductAttribute.sku => 'materialNumber',
        ProductAttribute.colour || ProductAttribute.subCategory => 'colour',
        ProductAttribute.profile || ProductAttribute.size => 'profile',
        ProductAttribute.family => 'family',
        ProductAttribute.brand => 'brand',
        ProductAttribute.grade => 'grade',
        ProductAttribute.thickness => 'thickness',
        ProductAttribute.rawThickness => 'rawThickness',
        ProductAttribute.width => 'width',
        ProductAttribute.materialType => 'materialType',
        ProductAttribute.division => 'division',
        ProductAttribute.priceGroup => 'priceGroup',
        ProductAttribute.warehouse ||
        ProductAttribute.material ||
        ProductAttribute.length ||
        ProductAttribute.height ||
        ProductAttribute.diameter =>
          null,
      };

  bool get isServerField => wireName != null;

  /// The facet name the local Drift DAO whitelists, or null when the local
  /// catalog has no column for this attribute.
  ///
  /// [colour] and [profile] fold onto the columns the demo catalog already
  /// loads SAP's `TopColor` and `Profile` into, so a server-published schema
  /// still resolves against a locally synced catalog rather than skipping two
  /// of its steps offline.
  String? get localFacet => switch (this) {
        ProductAttribute.family => 'family',
        ProductAttribute.warehouse => 'warehouse',
        ProductAttribute.subCategory ||
        ProductAttribute.colour =>
          'subCategory',
        ProductAttribute.brand => 'brand',
        ProductAttribute.size || ProductAttribute.profile => 'size',
        ProductAttribute.grade => 'grade',
        ProductAttribute.material => 'material',
        ProductAttribute.length => 'length',
        ProductAttribute.width => 'width',
        ProductAttribute.height => 'height',
        ProductAttribute.diameter => 'diameter',
        ProductAttribute.thickness => 'thickness',
        ProductAttribute.rawThickness ||
        ProductAttribute.materialType ||
        ProductAttribute.division ||
        ProductAttribute.priceGroup ||
        ProductAttribute.sku =>
          null,
      };

  /// Resolves a schema's `attribute` string, in either vocabulary.
  ///
  /// Matches the enum member name first, then [wireName], so both `subCategory`
  /// (what the app's own mock schema publishes) and `Colour` (what the platform
  /// publishes) land on a usable member. Unknown values return null and the
  /// step carrying them is dropped — a rep in the field must never lose the
  /// whole configurator because one enum member arrived that this build has no
  /// column for.
  static ProductAttribute? tryParse(String raw) {
    final needle = raw.toLowerCase();
    for (final value in ProductAttribute.values) {
      if (value.name.toLowerCase() == needle) return value;
    }
    for (final value in ProductAttribute.values) {
      if (value.wireName?.toLowerCase() == needle) return value;
    }
    return null;
  }
}
