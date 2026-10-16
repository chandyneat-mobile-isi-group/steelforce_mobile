import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';

/// The filter hierarchies "SAP" publishes for the guided product finder, as
/// JSON-ready maps in the wire shape [CategoryFilterSchemaModel.fromJson]
/// parses.
///
/// This file is the *mock backend's* configuration, not the app's: it stands in
/// for a merchandising-maintained table in SAP. Nothing in `presentation/` or
/// `domain/` knows any of these step orders exist — swap this class for a Dio
/// call and every screen behaves identically. That indirection is the whole
/// point, so resist the temptation to "simplify" by reading it directly from
/// the UI.
///
/// The hierarchies below are rebuilt from the real material master in
/// `SAP_BP_Data.pbix`, and each one follows how that product is actually
/// specified across an ISI counter — which is why no two are the same shape:
///
///  * roofing is chosen by profile, then coating line, then gauge, then colour
///    (colour last, because a depot changes their mind about colour and
///    never about profile);
///  * a PU panel adds the core depth between profile and gauge, since PU20 vs
///    PU40 is a different product at the same steel thickness;
///  * flashings and gutters are specified by *girth* — the flat width of the
///    blank before folding — not by a catalogue size code;
///  * purlins and pipe close on grade rather than colour, because nothing in
///    those categories is painted;
///  * slit and folded sheet have no family step at all, because the whole
///    category is one product described by two dimensions;
///  * traded reinforcement puts the *mill* where roofing puts the coating
///    line, because it is bought-in stock and the mill is what a depot
///    with a spec actually cares about;
///  * K-Pipe and traded beams stop at two steps, because SAP holds no brand
///    or grade variation on those lines and a one-chip step is a wasted tap.
///
/// Anything not covered here falls back to [genericSchemaFor], so no category
/// is ever unreachable.
///
/// Attribute note: the colour step uses `subCategory`, which is the column the
/// demo catalog loads SAP's `TopColor` into. [ProductAttribute] has no `color`
/// member; when one is added, this file and the DAO facet whitelist change
/// together and nothing above the data layer notices.
class IsiFilterSchemaData {
  IsiFilterSchemaData._();

  static List<Map<String, dynamic>> schemas() => [
        _palmProfile(),
        _puPanels(),
        _accessories(),
        _coldForm(),
        _galvanizedPipe(),
        _kPipe(),
        _steelSheet(),
        _sheetBending(),
        _reinforcement(),
        _tradedSections(),
      ];

  // ── ISI product lines ───────────────────────────────────────────────

  /// Profile → Coating → Gauge → Colour.
  ///
  /// Coating sits above gauge because the coating line (PALM 50PPGL vs
  /// PALM 100PPGL vs PALM 150GL) is what the warranty is written against; the
  /// rep confirms it before quoting a thickness.
  static Map<String, dynamic> _palmProfile() => _schema(
        categoryId: IsiDemoCatalog.palmProfileCategoryId,
        categoryName: 'Palm Profile Roofing',
        steps: [
          _step(
              key: 'profile',
              label: 'Profile',
              attribute: 'family',
              style: 'list',
              role: 'family'),
          _step(
              key: 'coating',
              label: 'Coating Line',
              attribute: 'brand',
              style: 'chips'),
          _step(
              key: 'gauge',
              label: 'Gauge',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2),
          _step(
              key: 'colour',
              label: 'Colour',
              attribute: 'subCategory',
              style: 'chips'),
        ],
      );

  /// Panel → PU core → Gauge → Colour. The core depth is a distinct step
  /// because PU20 and PU40 are separate materials at the same steel gauge.
  static Map<String, dynamic> _puPanels() => _schema(
        categoryId: IsiDemoCatalog.puPanelCategoryId,
        categoryName: 'PU Insulated Panels',
        steps: [
          _step(
              key: 'panel',
              label: 'Panel',
              attribute: 'family',
              style: 'list',
              role: 'family'),
          _step(
              key: 'core', label: 'PU Core', attribute: 'size', style: 'chips'),
          _step(
              key: 'gauge',
              label: 'Gauge',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2),
          _step(
              key: 'colour',
              label: 'Colour',
              attribute: 'subCategory',
              style: 'chips'),
        ],
      );

  /// Accessory → Girth → Gauge → Colour. Girth is the flat blank width, so it
  /// is read off `width`, not `size` — a 600 gutter and a 400 gutter are the
  /// same fold from different blanks.
  static Map<String, dynamic> _accessories() => _schema(
        categoryId: IsiDemoCatalog.accessoriesCategoryId,
        categoryName: 'Roofing Accessories',
        steps: [
          _step(
              key: 'accessory',
              label: 'Accessory',
              attribute: 'family',
              style: 'list',
              role: 'family'),
          _step(
              key: 'girth',
              label: 'Girth',
              attribute: 'width',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 0),
          _step(
              key: 'gauge',
              label: 'Gauge',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2),
          _step(
              key: 'colour',
              label: 'Colour',
              attribute: 'subCategory',
              style: 'chips'),
        ],
      );

  /// Section → Size → Thickness → Grade. Structural, so it closes on grade;
  /// the SGCC-Z60 / G450-Z275 distinction is load-bearing, not cosmetic.
  static Map<String, dynamic> _coldForm() => _schema(
        categoryId: IsiDemoCatalog.coldFormCategoryId,
        categoryName: 'Cold Formed Sections',
        steps: [
          _step(
              key: 'section',
              label: 'Section',
              attribute: 'family',
              style: 'list',
              role: 'family'),
          _step(key: 'size', label: 'Size', attribute: 'size', style: 'grid'),
          _step(
              key: 'thickness',
              label: 'Thickness',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2),
          _step(
              key: 'grade', label: 'Grade', attribute: 'grade', style: 'chips'),
        ],
      );

  /// Section → Size → Wall → Grade.
  ///
  /// Round, square and rectangular are three SAP product groups but one buying
  /// decision, so they share a category and split at the family step. Round
  /// pipe also populates `diameter`, which the generic fallback can pick up.
  static Map<String, dynamic> _galvanizedPipe() => _schema(
        categoryId: IsiDemoCatalog.giPipeCategoryId,
        categoryName: 'Galvanized Pipes',
        steps: [
          _step(
              key: 'section',
              label: 'Section',
              attribute: 'family',
              style: 'list',
              role: 'family'),
          _step(key: 'size', label: 'Size', attribute: 'size', style: 'grid'),
          _step(
              key: 'wall',
              label: 'Wall Thickness',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2),
          _step(
              key: 'grade',
              label: 'Coating Class',
              attribute: 'grade',
              style: 'chips'),
        ],
      );

  /// Size → Thickness, and nothing else.
  ///
  /// SAP carries `Brand` and `Grade` as the literal string "NA" on all 117
  /// K-Pipe materials, so a coating or grade step would render exactly one
  /// meaningless chip. Two steps is the honest shape of this line.
  static Map<String, dynamic> _kPipe() => _schema(
        categoryId: IsiDemoCatalog.kPipeCategoryId,
        categoryName: 'K-Pipe',
        steps: [
          _step(key: 'size', label: 'Size', attribute: 'size', style: 'grid'),
          _step(
              key: 'thickness',
              label: 'Wall Thickness',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2),
        ],
      );

  /// Width → Thickness → Grade. Slit coil: no family step, because the whole
  /// category is one product described by two dimensions.
  static Map<String, dynamic> _steelSheet() => _schema(
        categoryId: IsiDemoCatalog.steelSheetCategoryId,
        categoryName: 'GI Steel Sheet',
        steps: [
          _step(
              key: 'width',
              label: 'Width',
              attribute: 'width',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 0),
          _step(
              key: 'thickness',
              label: 'Thickness',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2),
          _step(
              key: 'grade', label: 'Grade', attribute: 'grade', style: 'chips'),
        ],
      );

  /// Same steel as [_steelSheet], already folded. Identical hierarchy, kept as
  /// its own schema so the two can diverge without a conditional.
  static Map<String, dynamic> _sheetBending() => _schema(
        categoryId: IsiDemoCatalog.sheetBendingCategoryId,
        categoryName: 'GI Steel Bending',
        steps: [
          _step(
              key: 'width',
              label: 'Width',
              attribute: 'width',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 0),
          _step(
              key: 'thickness',
              label: 'Thickness',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2),
          _step(
              key: 'grade', label: 'Grade', attribute: 'grade', style: 'chips'),
        ],
      );

  /// Product → Mill → Grade → Diameter.
  ///
  /// The only category where `brand` is a *supplier* rather than an ISI
  /// coating line: this is bought-in stock (MaterialType HAWA), and Tung Ho
  /// vs Hoa Phat vs Hai Sheng is a real decision for a depot working to a
  /// spec. Mill sits above grade because a mill only certifies some grades.
  ///
  /// Bar diameter arrives in SAP's `SaleThickness_mm` column, but it is a
  /// diameter, so the demo catalog loads it into `diameter` and this step
  /// reads it from there. Do not "correct" this to `thickness`.
  static Map<String, dynamic> _reinforcement() => _schema(
        categoryId: IsiDemoCatalog.reinforcementCategoryId,
        categoryName: 'Reinforcement (Traded)',
        steps: [
          _step(
              key: 'product',
              label: 'Product',
              attribute: 'family',
              style: 'list',
              role: 'family'),
          _step(key: 'mill', label: 'Mill', attribute: 'brand', style: 'chips'),
          _step(
              key: 'grade', label: 'Grade', attribute: 'grade', style: 'chips'),
          _step(
              key: 'diameter',
              label: 'Bar Diameter',
              attribute: 'diameter',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 1),
        ],
      );

  /// Section → Size. Every beam ISI resells is SS400 from POSCO, so grade and
  /// brand are constant across the line and neither earns a step — adding one
  /// would cost a tap and tell the rep nothing.
  static Map<String, dynamic> _tradedSections() => _schema(
        categoryId: IsiDemoCatalog.tradedSectionCategoryId,
        categoryName: 'Beams (Traded)',
        steps: [
          _step(
              key: 'section',
              label: 'Section',
              attribute: 'family',
              style: 'list',
              role: 'family'),
          _step(key: 'size', label: 'Size', attribute: 'size', style: 'grid'),
        ],
      );

  // ── Fallback ────────────────────────────────────────────────────────

  /// The hierarchy served for any category ISI hasn't published a bespoke one
  /// for (the legacy generated catalog). Every step is optional, and the flow
  /// skips any that resolves to no options, so one template covers categories
  /// with wildly different attribute coverage.
  static Map<String, dynamic> genericSchemaFor({
    required String categoryId,
    required String categoryName,
  }) =>
      _schema(
        categoryId: categoryId,
        categoryName: categoryName,
        steps: [
          _step(
              key: 'family',
              label: 'Product Family',
              attribute: 'family',
              style: 'list',
              role: 'family',
              required: false),
          _step(
              key: 'brand',
              label: 'Brand',
              attribute: 'brand',
              style: 'chips',
              required: false),
          _step(
              key: 'grade',
              label: 'Grade',
              attribute: 'grade',
              style: 'chips',
              required: false),
          _step(
              key: 'size',
              label: 'Size',
              attribute: 'size',
              style: 'grid',
              required: false),
          _step(
              key: 'diameter',
              label: 'Diameter',
              attribute: 'diameter',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 1,
              required: false),
          _step(
              key: 'thickness',
              label: 'Thickness',
              attribute: 'thickness',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 2,
              required: false),
          _step(
              key: 'width',
              label: 'Width',
              attribute: 'width',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'mm',
              decimals: 0,
              required: false),
          _step(
              key: 'length',
              label: 'Length',
              attribute: 'length',
              style: 'grid',
              role: 'dimension',
              unitSuffix: 'm',
              decimals: 2,
              required: false),
          _step(
              key: 'finish',
              label: 'Finish',
              attribute: 'subCategory',
              style: 'chips',
              required: false),
        ],
      );

  // ── Builders ────────────────────────────────────────────────────────

  static Map<String, dynamic> _schema({
    required String categoryId,
    required String categoryName,
    required List<Map<String, dynamic>> steps,
  }) {
    for (var i = 0; i < steps.length; i++) {
      steps[i]['sortOrder'] = i;
    }
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'steps': steps,
    };
  }

  static Map<String, dynamic> _step({
    required String key,
    required String label,
    required String attribute,
    required String style,
    String role = 'specification',
    String? unitSuffix,
    int? decimals,
    bool required = true,
  }) =>
      {
        'key': key,
        'label': label,
        'attribute': attribute,
        'sortOrder': 0, // overwritten by _schema
        'style': style,
        'role': role,
        'unitSuffix': unitSuffix,
        'decimals': decimals,
        'required': required,
      };
}
