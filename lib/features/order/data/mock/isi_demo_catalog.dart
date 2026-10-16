/// Demo catalog for the guided product finder, transcribed from the **real ISI
/// material master** exported in `SAP_BP_Data.pbix` (Material table, 20,088
/// rows / 4,137 distinct sellable SKUs as of the 2026-07-02 extract).
///
/// Every material number, description, Khmer description, profile, coating
/// brand, grade, gauge, girth and net weight below is a verbatim SAP value —
/// not an invention. What ISI actually sells is roll-formed and cold-formed
/// coated steel: Palm Profile roofing, PU sandwich panels, roofing
/// accessories, purlins and decking, galvanized pipe, K-Pipe, and slit/folded
/// GI sheet. Beams and reinforcement are here too, but as *traded* goods
/// (MaterialType HAWA) at a fraction of the volume — 11 H-Beam and 111
/// Deformed Bar rows against 1,397 for Palm Profile alone. The previous
/// version of this file made those the centre of the catalog and invented the
/// specs, so the configurator demoed a picker weighted the wrong way round.
///
/// Watch out for `ProductGroup` when extending this: it is blank on 11,832
/// distinct materials, and that blank set is not all spares. K-Pipe (117
/// rows, FERT), Deformed Bar (111, HAWA) and the beams all live there. Filter
/// on `MaterialType in (FERT, HAWA, KMAT)` to find what is sellable, and use
/// `MaterialGroupName` — not `ProductGroup` — as the family key.
///
/// Descriptions are copied byte-for-byte, including SAP's own damage: MAKTX is
/// 40 characters and 846 rows in the extract sit exactly on that limit, so
/// `GI Steel Sheet 1250x0.80x2.41m (SGCC-Z60` really does lose its closing
/// bracket in the source system. Left as-is on purpose — the demo should show
/// what a rep will actually see on the device, and if that's ugly enough to
/// prompt a data-cleanup ticket in SAP, so much the better.
///
/// **Prices are the one synthesized field**, and net weight is synthesized for
/// the traded reinforcement rows only. The .pbix carries no condition
/// records (no KONV/A004), so `price` is derived deterministically as net
/// weight x a per-category USD/kg rate. Swap [_sku]'s pricing block the moment
/// a real price extract lands; nothing else here needs to change.
///
/// On the HAWA reinforcement rows SAP carries `NetWeight` as a flat 1.0
/// placeholder, so those weights come from the standard bar-mass formula
/// (0.00617 x d^2 kg/m, x 12 m stock length) rather than from the extract.
/// Every other weight in this file is the real `NetWeight`.
///
/// Deliberately tiny and hand-written rather than combinatorially generated:
/// **exactly six SKUs per category**, chosen so every branch of that category's
/// filter schema in `isi_filter_schema_data.dart` is walkable and every leaf
/// lands on a real product. Each category contributes three families x two
/// SKUs that differ on exactly one downstream step, so the picker visibly
/// branches instead of collapsing to a single row. That makes the whole flow
/// testable by hand in a couple of minutes — which the 20k-row generated
/// catalog (`mock_product_data.dart`) is not, and which is the point of
/// keeping the two separate.
///
/// Ten categories, not the nine SAP `ProductGroup` values: round, square and
/// rectangular pipe are three product groups but one buying decision, so they
/// share a category and split at the family step.
///
/// SAP field -> catalog column, so the mapping is auditable:
///
/// | SAP (Material)      | Catalog column          |
/// |---------------------|-------------------------|
/// | ProductGroup        | categoryId              |
/// | Profile / MatGroup  | familyId + familyName   |
/// | Material            | materialCode            |
/// | MaterialDes         | name                    |
/// | MaterialDesKH       | description (Khmer)     |
/// | Brand               | brand (coating line)    |
/// | Grade               | grade                   |
/// | TopColor            | subCategory (finish)    |
/// | SaleThickness_mm    | thickness               |
/// | Width_mm            | width (girth / coil)    |
/// | Profile (round pipe)| diameter                |
/// | NetWeight           | weight                  |
/// | BaseUnit            | unit (M / PCS)          |
///
/// `subCategory` carries the colour because [ProductAttribute] has no `color`
/// member and colour is genuinely the last thing a roofing depot chooses.
/// If a real `color` attribute is ever added to the domain enum, the DAO facet
/// whitelist and this column move together — nothing above the data layer
/// depends on the alias.
///
/// Emits the same JSON shape as [MockProductData] so both flow through the
/// identical sync -> local-catalog path. Warehouses sit inside the default
/// [SyncScope] so the rows survive scoping on a fresh install.
class IsiDemoCatalog {
  IsiDemoCatalog._();

  static const palmProfileCategoryId = 'cat_isi_palm_profile';
  static const puPanelCategoryId = 'cat_isi_pu_palm';
  static const accessoriesCategoryId = 'cat_isi_palm_accessories';
  static const coldFormCategoryId = 'cat_isi_cold_form';
  static const giPipeCategoryId = 'cat_isi_gi_pipe';
  static const kPipeCategoryId = 'cat_isi_k_pipe';
  static const steelSheetCategoryId = 'cat_isi_steel_sheet';
  static const sheetBendingCategoryId = 'cat_isi_sheet_bending';
  static const reinforcementCategoryId = 'cat_isi_reinforcement';
  static const tradedSectionCategoryId = 'cat_isi_traded_sections';

  static const _warehouse = 'WH-PP01';
  static const _territory = 'Phnom Penh';
  static const _businessUnit = 'ISI Steel';

  /// Category rows in the order the finder should offer them: roofing first
  /// (it is the volume line by an order of magnitude), then the formed and
  /// pipe lines, then the semi-finished flat products, then the traded goods
  /// last because they are the thinnest range. Negative sort orders keep them
  /// ahead of the bulk generated trading catalog.
  /// Every row carries **both** languages. A category with only `name` renders
  /// its English label to a Khmer-speaking rep — the fallback in
  /// [LocalizedText.resolve] is a safety net for missing SAP data, not a
  /// licence to ship half-translated master data. `catalog_localization_test`
  /// fails the build if a row here loses its Khmer.
  ///
  /// `code` is the SAP `ProductGroup`, kept explicit rather than defaulted from
  /// the id so a taxonomy rename never silently repoints the mapping.
  static List<Map<String, dynamic>> categories() => const [
        {
          'id': palmProfileCategoryId,
          'parentId': null,
          'code': 'PALM_PROFILE',
          'name': 'Palm Profile Roofing',
          'nameKh': 'ស័ង្កសី ផាម ភ្លី',
          'icon': 'roofing',
          'sortOrder': -10,
        },
        {
          'id': puPanelCategoryId,
          'parentId': null,
          'code': 'PU_PANEL',
          'name': 'PU Insulated Panels',
          'nameKh': 'ផ្ទាំង PU អ៊ីសូឡង់',
          'icon': 'panel',
          'sortOrder': -9,
        },
        {
          'id': accessoriesCategoryId,
          'parentId': null,
          'code': 'PALM_ACCESSORIES',
          'name': 'Roofing Accessories',
          'nameKh': 'គ្រឿងបន្លាស់ដំបូល',
          'icon': 'accessory',
          'sortOrder': -8,
        },
        {
          'id': coldFormCategoryId,
          'parentId': null,
          'code': 'COLD_FORM',
          'name': 'Cold Formed Sections',
          'nameKh': 'ដែករាងបត់ត្រជាក់',
          'icon': 'section',
          'sortOrder': -7,
        },
        {
          'id': giPipeCategoryId,
          'parentId': null,
          'code': 'GI_PIPE',
          'name': 'Galvanized Pipes',
          'nameKh': 'បំពង់ស័ង្កសី',
          'icon': 'pipe',
          'sortOrder': -6,
        },
        {
          'id': kPipeCategoryId,
          'parentId': null,
          'code': 'K_PIPE',
          'name': 'K-Pipe',
          'nameKh': 'បំពង់ K',
          'icon': 'pipe',
          'sortOrder': -5,
        },
        {
          'id': steelSheetCategoryId,
          'parentId': null,
          'code': 'STEEL_SHEET',
          'name': 'GI Steel Sheet',
          'nameKh': 'សន្លឹកដែកស័ង្កសី',
          'icon': 'sheet',
          'sortOrder': -4,
        },
        {
          'id': sheetBendingCategoryId,
          'parentId': null,
          'code': 'SHEET_BENDING',
          'name': 'GI Steel Bending',
          'nameKh': 'ដែកស័ង្កសីបត់',
          'icon': 'bending',
          'sortOrder': -3,
        },
        {
          'id': reinforcementCategoryId,
          'parentId': null,
          'code': 'REINFORCEMENT',
          'name': 'Reinforcement (Traded)',
          'nameKh': 'ដែកពង្រឹង (ជួញដូរ)',
          'icon': 'rebar',
          'sortOrder': -2,
        },
        {
          'id': tradedSectionCategoryId,
          'parentId': null,
          'code': 'TRADED_SECTIONS',
          'name': 'Beams (Traded)',
          'nameKh': 'ធ្នឹមដែក (ជួញដូរ)',
          'icon': 'beam',
          'sortOrder': -1,
        },
      ];

  /// 10 categories x 6 SKUs = 60 demo rows.
  static List<Map<String, dynamic>> products() => [
        ..._palm(),
        ..._pu(),
        ..._acc(),
        ..._cold(),
        ..._pipe(),
        ..._kpipe(),
        ..._sheet(),
        ..._bend(),
        ..._rebar(),
        ..._sections(),
      ];

  // -- 1. Palm Profile roofing: Profile -> Coating -> Thickness -> Colour ----
  // Sold by the linear metre off the roll-former; the profile name is
  // the trade name a depot asks for by ("give me TRIM-7 in brick red").

  static List<Map<String, dynamic>> _palm() => [
        _sku(
            categoryId: palmProfileCategoryId,
            materialNumber: '1400000691',
            seq: 1,
            family: 'TRIM-7',
            name: 'TRIM-7 YL 0.30mm-PALM 50PPGL',
            nameKh: 'ស័ង្កសី ផាម ភ្លីជ្រុង 1000-7 លឿង 0.30mm-PALM 50PPGL',
            finish: 'Yellow',
            brand: 'PALM 50PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'TRIM-7',
            thickness: 0.3,
            width: 1200.0,
            weight: 2.246,
            unit: 'M',
            price: 3.48),
        _sku(
            categoryId: palmProfileCategoryId,
            materialNumber: '1400000732',
            seq: 2,
            family: 'TRIM-7',
            name: 'TRIM-7 BR 0.40x3m-PALM 100PPGL',
            nameKh: 'ស័ង្កសី ផាម ភ្លីជ្រុង 1000-7 ក្រហម 0.40x3m-PALM AM100PPGL',
            finish: 'Brick Red',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'TRIM-7',
            thickness: 0.4,
            width: 1200.0,
            weight: 10.37,
            unit: 'PCS',
            price: 16.07),
        _sku(
            categoryId: palmProfileCategoryId,
            materialNumber: '2400001018',
            seq: 3,
            family: 'TILE 1000',
            name: 'TILE 1000 GL 0.30mm-PALM 70GL',
            nameKh: 'ស័ង្កសី ផាម ភ្លីក្បឿង 1000 ញ៉ូម 0.30mm-PALM 70GL',
            finish: 'Gavalume',
            brand: 'PALM 70GL',
            grade: 'G300AZ70',
            material: 'Aluzinc Coated Steel',
            size: 'TILE 1000',
            thickness: 0.3,
            width: 1200.0,
            weight: 2.66,
            unit: 'M',
            price: 4.12),
        _sku(
            categoryId: palmProfileCategoryId,
            materialNumber: '2400001070',
            seq: 4,
            family: 'TILE 1000',
            name: 'TILE 1000 BR 0.30mm-PALM 50PPGL',
            nameKh: 'ស័ង្កសី ផាម ភ្លីក្បឿង 1000 ក្រហម 0.30mm-PALM 50PPGL',
            finish: 'Brick Red',
            brand: 'PALM 50PPGL',
            grade: 'G300AZ50',
            material: 'Aluzinc Coated Steel',
            size: 'TILE 1000',
            thickness: 0.3,
            width: 1200.0,
            weight: 2.25,
            unit: 'M',
            price: 3.49),
        _sku(
            categoryId: palmProfileCategoryId,
            materialNumber: '2400001024',
            seq: 5,
            family: 'WAVE MAX 950',
            name: 'WAVE 950 GL 0.30mm-PALM 70GL',
            nameKh: 'ស័ង្កសី ផាម ភ្លីរលក​ 950 ញ៉ូម 0.30mm-PALM 70GL',
            finish: 'Gavalume',
            brand: 'PALM 70GL',
            grade: 'G300AZ70',
            material: 'Aluzinc Coated Steel',
            size: 'WAVE MAX 950',
            thickness: 0.3,
            width: 1200.0,
            weight: 2.66,
            unit: 'M',
            price: 4.12),
        _sku(
            categoryId: palmProfileCategoryId,
            materialNumber: '2400001072',
            seq: 6,
            family: 'WAVE MAX 950',
            name: 'WAVE 950 BR 0.30mm-PALM 50PPGL',
            nameKh: 'ស័ង្កសី ផាម ភ្លីរលក​ 950 ក្រហម 0.30mm-PALM 50PPGL',
            finish: 'Brick Red',
            brand: 'PALM 50PPGL',
            grade: 'G300AZ50',
            material: 'Aluzinc Coated Steel',
            size: 'WAVE MAX 950',
            thickness: 0.3,
            width: 1200.0,
            weight: 2.25,
            unit: 'M',
            price: 3.49),
      ];

  // -- 2. PU insulated panels: Panel -> PU core -> Thickness -> Colour ----
  // The PU core depth (PU20/PU30/PU40) is the spec that drives price and
  // insulation, and it is orthogonal to the steel gauge above it.

  static List<Map<String, dynamic>> _pu() => [
        _sku(
            categoryId: puPanelCategoryId,
            materialNumber: '1400001078',
            seq: 1,
            family: 'CAP 980PU',
            name: 'CAP 980PU20 GL 0.40x4.3m-GL0.25-PALM 100',
            nameKh:
                'ស័ង្កសី ភ្លីមួក 980 PU20  ញ៉ូម 0.400x4.3m ពិដាន ញ៉ូម 0.250mm-PALM100GL',
            finish: 'Gavalume',
            brand: 'PALM 100GL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'PU20',
            thickness: 0.4,
            width: 1200.0,
            weight: 14.861,
            unit: 'PCS',
            price: 17.09),
        _sku(
            categoryId: puPanelCategoryId,
            materialNumber: '1400001112',
            seq: 2,
            family: 'CAP 980PU',
            name: 'CAP 980PU40 CG 0.40x7.65m-SW0.25-PALM 10',
            nameKh:
                'ស័ង្កសី ភ្លីមួក​ 980 PU40 ប្រផេះខ្ចី 0.40x7.65m ពិដាន ស ព្រិល 0.25mm-PALM 100PPG',
            finish: 'Cambo Grey',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'PU40',
            thickness: 0.4,
            width: 1200.0,
            weight: 6.48,
            unit: 'PCS',
            price: 7.45),
        _sku(
            categoryId: puPanelCategoryId,
            materialNumber: '1400000900',
            seq: 3,
            family: 'CAP 980PU ECO',
            name: 'CAP 980PU40 ECO DB 0.40x2.3m-SW0.25-PALM',
            nameKh:
                'ស័ង្កសី ភ្លីមួក 980 PU40 ECO ខៀវចាស់ 0.40x2.3m ពិដានសព្រិល 0.25mm-PALM 50PPGL',
            finish: 'Dark Blue',
            brand: 'PALM 50PPGL',
            grade: 'G300AZ50',
            material: 'Aluzinc Coated Steel',
            size: 'PU40',
            thickness: 0.4,
            width: 1200.0,
            weight: 7.154,
            unit: 'PCS',
            price: 8.23),
        _sku(
            categoryId: puPanelCategoryId,
            materialNumber: '2400003465',
            seq: 4,
            family: 'CAP 980PU ECO',
            name: 'CAP 980PU20 ECO LB 0.40mm-AL-PALM 50',
            nameKh:
                'ស័ង្កសី ភ្លីមួក 980 PU20 ECO ខៀវស្រស់ 0.40mm ក្រដាសអាលុយមីញ៉ូម-PALM 50PPGL',
            finish: 'Light Blue',
            brand: 'PALM 50PPGL',
            grade: 'G300AZ50',
            material: 'Aluzinc Coated Steel',
            size: 'PU20',
            thickness: 0.4,
            width: 1200.0,
            weight: 4.48,
            unit: 'M',
            price: 5.15),
        _sku(
            categoryId: puPanelCategoryId,
            materialNumber: '2400000811',
            seq: 5,
            family: 'COOL TILE',
            name: 'COOL TILE SB 0.45-AL-PALM 100PPGL',
            nameKh:
                'ក្បឿងត្រជាក់ ផ្ទៃមេឃ 0.45mm ក្រដាសអាលុយមីញ៉ូម-PALM AM100PPGL',
            finish: 'Sky Blue',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'PU20',
            thickness: 0.45,
            width: 1200.0,
            weight: 5.45,
            unit: 'M',
            price: 6.27),
        _sku(
            categoryId: puPanelCategoryId,
            materialNumber: '2400000813',
            seq: 6,
            family: 'COOL TILE',
            name: 'COOL TILE NB 0.45-AL-PALM 100PPGL',
            nameKh:
                'ក្បឿងត្រជាក់ ខៀវធម្មជាតិ 0.45mm ក្រដាសអាលុយមីញ៉ូម-PALM AM100PPGL',
            finish: 'Nature Blue',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'PU20',
            thickness: 0.45,
            width: 1200.0,
            weight: 5.45,
            unit: 'M',
            price: 6.27),
      ];

  // -- 3. Roofing accessories: Accessory -> Girth -> Thickness -> Colour ----
  // Flashings and gutters are specified by *girth* — the flat width of
  // the blank before folding — which is why width, not size, is the step.

  static List<Map<String, dynamic>> _acc() => [
        _sku(
            categoryId: accessoriesCategoryId,
            materialNumber: '1400000730',
            seq: 1,
            family: 'GUTTER',
            name: 'Gutter BR 400x0.40x3.5m PALM 100PPGL',
            nameKh: 'ស័ង្កសី ទរទឹក  ក្រហម 400x0.40x3.5m PALM AM100PPGL',
            finish: 'Brick Red',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'GUTTER',
            thickness: 0.4,
            width: 400.0,
            weight: 6.05,
            unit: 'PCS',
            price: 9.68),
        _sku(
            categoryId: accessoriesCategoryId,
            materialNumber: '2400002043',
            seq: 2,
            family: 'GUTTER',
            name: 'Gutter 600 SB 0.40mm-PALM 100PPGL',
            nameKh: 'ស័ង្កសី ទរទឹក 600 ផ្ទៃមេឃ 0.40mm-PALM AM100PPGL',
            finish: 'Sky Blue',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'GUTTER',
            thickness: 0.4,
            width: 600.0,
            weight: 1.73,
            unit: 'M',
            price: 2.77),
        _sku(
            categoryId: accessoriesCategoryId,
            materialNumber: '1400000720',
            seq: 3,
            family: 'FLASHING',
            name: 'Flashing GL 1200x0.50x4.20m-PALM 100GL',
            nameKh: 'ស័ង្កសី ជ្រី-ញ៉ូម 1200x0.50x4.20m-PALM AM100GL',
            finish: 'Gavalume',
            brand: 'PALM 100GL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'FLASHING',
            thickness: 0.5,
            width: 1200.0,
            weight: 18.648,
            unit: 'PCS',
            price: 29.84),
        _sku(
            categoryId: accessoriesCategoryId,
            materialNumber: '1400000777',
            seq: 4,
            family: 'FLASHING',
            name: 'Flashing CG 400x0.40x5.34m PALM 100PPGL',
            nameKh: 'ស័ង្កសី ជ្រី-ប្រផេះខ្ចី 400x0.40x5.34m-PALM AM100PPGL',
            finish: 'Cambo Grey',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'FLASHING',
            thickness: 0.4,
            width: 400.0,
            weight: 9.99,
            unit: 'M',
            price: 15.98),
        _sku(
            categoryId: accessoriesCategoryId,
            materialNumber: '2400000851',
            seq: 5,
            family: 'PALM HAT',
            name: 'PALM Hat SB 0.40mm-PALM 100PPGL',
            nameKh: 'ស័ង្កសី ផាម គម្រប ផ្ទៃមេឃ 0.40mm-PALM AM100PPGL',
            finish: 'Sky Blue',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'PALM HAT',
            thickness: 0.4,
            width: 75.0,
            weight: 0.22,
            unit: 'M',
            price: 0.64),
        _sku(
            categoryId: accessoriesCategoryId,
            materialNumber: '2400000854',
            seq: 6,
            family: 'PALM HAT',
            name: 'PALM Hat NB 0.40mm-PALM 100PPGL',
            nameKh: 'ស័ង្កសី ផាម គម្រប ខៀវធម្មជាតិ 0.40mm-PALM AM100PPGL',
            finish: 'Nature Blue',
            brand: 'PALM 100PPGL',
            grade: 'G300AZ100',
            material: 'Aluzinc Coated Steel',
            size: 'PALM HAT',
            thickness: 0.4,
            width: 75.0,
            weight: 0.22,
            unit: 'M',
            price: 0.64),
      ];

  // -- 4. Cold formed sections: Section -> Size -> Thickness -> Grade ----
  // Purlins and decking are structural, so grade closes the flow rather
  // than colour; nothing in this category is painted.

  static List<Map<String, dynamic>> _cold() => [
        _sku(
            categoryId: coldFormCategoryId,
            materialNumber: '1400000891',
            seq: 1,
            family: 'C-Purlin',
            name: 'C Purlin 150x65x3.00x6m (SGCC-Z60)',
            nameKh: 'ដែក C ស 150x65-3.00x6m - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'C PURLIN',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '150X65',
            thickness: 3.0,
            width: 295.0,
            weight: 41.577,
            unit: 'PCS',
            price: 53.22),
        _sku(
            categoryId: coldFormCategoryId,
            materialNumber: '1400000892',
            seq: 2,
            family: 'C-Purlin',
            name: 'C Purlin 125x50x2.90x6m (SGCC-Z60)',
            nameKh: 'ដែក C ស 125X50X2.90x6m - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'C PURLIN',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '125X50',
            thickness: 2.9,
            width: 230.0,
            weight: 31.336,
            unit: 'PCS',
            price: 40.11),
        _sku(
            categoryId: coldFormCategoryId,
            materialNumber: '1400000852',
            seq: 3,
            family: 'Z-Purlin',
            name: 'Z Purlin 75x40x1.80x6m (SGCC-Z60)',
            nameKh: 'ដែក Z ស 75x40-1.80x6m - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'Z PURLIN',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '75X40',
            thickness: 1.8,
            width: 170.0,
            weight: 14.376,
            unit: 'PCS',
            price: 18.4),
        _sku(
            categoryId: coldFormCategoryId,
            materialNumber: '2400000568',
            seq: 4,
            family: 'Z-Purlin',
            name: 'Z Purlin 100x50x1.20 (SGCC-Z60)',
            nameKh: 'ដែក Z ស 100x50-1.20mm - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'Z PURLIN',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '100X50',
            thickness: 1.2,
            width: 210.0,
            weight: 1.97,
            unit: 'M',
            price: 2.52),
        _sku(
            categoryId: coldFormCategoryId,
            materialNumber: '1400000858',
            seq: 5,
            family: 'Decking',
            name: 'DECKING 1000x1.00x3m (SGCC-Z60)',
            nameKh: 'ដែក DECK 1000-1.00x3m - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'DECK',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '1000',
            thickness: 1.0,
            width: 1219.0,
            weight: 28.634,
            unit: 'PCS',
            price: 36.65),
        _sku(
            categoryId: coldFormCategoryId,
            materialNumber: '2400000544',
            seq: 6,
            family: 'Decking',
            name: 'DECKING 688x1.00 (G450-Z275)',
            nameKh: 'ដែក DECK 688-1.00mm - G450-Z275',
            finish: 'Mill Finish',
            brand: 'DECK',
            grade: 'G450-Z275',
            material: 'High-Tensile Galvanized Steel',
            size: '688',
            thickness: 1.0,
            width: 415.0,
            weight: 7.697,
            unit: 'M',
            price: 9.85),
      ];

  // -- 5. Galvanized pipes: Section -> Size -> Wall -> Grade -------------
  // Round, square and rectangular are three SAP product groups but one
  // buying decision, so they share a category and split at the family step.

  static List<Map<String, dynamic>> _pipe() => [
        _sku(
            categoryId: giPipeCategoryId,
            materialNumber: '2400002848',
            seq: 1,
            family: 'Round-GI',
            name: 'Galvanized Round Pipe 127x2.30',
            nameKh: 'ដែកទីប-ស មូល 127x2.30',
            finish: 'Mill Finish',
            brand: 'ISI PIPE',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '127',
            diameter: 127.0,
            thickness: 2.3,
            width: 392.0,
            weight: 6.753,
            unit: 'M',
            price: 8.37),
        _sku(
            categoryId: giPipeCategoryId,
            materialNumber: '2400004576',
            seq: 2,
            family: 'Round-GI',
            name: 'Galvanized Round Pipe 42x3.00',
            nameKh: 'ដែកទីប-ស មូល 42x3.00',
            finish: 'Mill Finish',
            brand: 'ISI PIPE',
            grade: 'SGCC-Z180',
            material: 'Hot-Dip Galvanized Steel',
            size: '42',
            diameter: 42.0,
            thickness: 3.0,
            width: 130.0,
            weight: 2.952,
            unit: 'M',
            price: 3.66),
        _sku(
            categoryId: giPipeCategoryId,
            materialNumber: '2400002686',
            seq: 3,
            family: 'Square-GI',
            name: 'Galvanized Square Pipe 100x100x2.60',
            nameKh: 'ដែកទីប-ស ជ្រុង 100x100x2.60',
            finish: 'Mill Finish',
            brand: 'ISI PIPE',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '100X100',
            thickness: 2.6,
            width: 391.0,
            weight: 7.654,
            unit: 'M',
            price: 9.49),
        _sku(
            categoryId: giPipeCategoryId,
            materialNumber: '2400002704',
            seq: 4,
            family: 'Square-GI',
            name: 'Galvanized Square Pipe 75x75x2.60',
            nameKh: 'ដែកទីប-ស ជ្រុង 75x75x2.60',
            finish: 'Mill Finish',
            brand: 'ISI PIPE',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '75X75',
            thickness: 2.6,
            width: 291.0,
            weight: 5.697,
            unit: 'M',
            price: 7.06),
        _sku(
            categoryId: giPipeCategoryId,
            materialNumber: '2400002578',
            seq: 5,
            family: 'Rectangular-GI',
            name: 'Galvanized Rect. Pipe 75x125x2.20',
            nameKh: 'ដែកទីប-ស ជ្រុង 75x125x2.20',
            finish: 'Mill Finish',
            brand: 'ISI PIPE',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '75X125',
            thickness: 2.2,
            width: 392.0,
            weight: 6.463,
            unit: 'M',
            price: 8.01),
        _sku(
            categoryId: giPipeCategoryId,
            materialNumber: '2400002596',
            seq: 6,
            family: 'Rectangular-GI',
            name: 'Galvanized Rect. Pipe 50x100x2.50',
            nameKh: 'ដែកទីប-ស ជ្រុង 50x100x2.50',
            finish: 'Mill Finish',
            brand: 'ISI PIPE',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '50X100',
            thickness: 2.5,
            width: 291.0,
            weight: 5.469,
            unit: 'M',
            price: 6.78),
      ];

  // -- 6. K-Pipe: Size -> Thickness --------------------------------------
  // ISI's own light-gauge square tube, a separate brand line from the
  // ISI PIPE range above. Two steps only: SAP carries no brand or grade on
  // this material group, so a third step would render one empty chip.

  static List<Map<String, dynamic>> _kpipe() => [
        _sku(
            categoryId: kPipeCategoryId,
            materialNumber: '1400001137',
            seq: 1,
            family: 'K Pipe-GI',
            name: 'Galvanized K Pipe 20x20x0.80x6m',
            nameKh: 'ដែកទីប-ស ជ្រុង K 20x20x0.80',
            finish: 'Mill Finish',
            brand: 'ISI K-PIPE',
            grade: 'Commercial',
            material: 'Hot-Dip Galvanized Steel',
            size: '20X20',
            thickness: 0.8,
            weight: 2.401,
            unit: 'PCS',
            price: 2.93),
        _sku(
            categoryId: kPipeCategoryId,
            materialNumber: '1400001046',
            seq: 2,
            family: 'K Pipe-GI',
            name: 'Galvanized K Pipe 20x20x0.90x6m',
            nameKh: 'ដែកទីប-ស ជ្រុង K 20x20x0.90',
            finish: 'Mill Finish',
            brand: 'ISI K-PIPE',
            grade: 'Commercial',
            material: 'Hot-Dip Galvanized Steel',
            size: '20X20',
            thickness: 0.9,
            weight: 2.781,
            unit: 'PCS',
            price: 3.39),
        _sku(
            categoryId: kPipeCategoryId,
            materialNumber: '1400001138',
            seq: 3,
            family: 'K Pipe-GI',
            name: 'Galvanized K Pipe 25x25x0.80x6m',
            nameKh: 'ដែកទីប-ស ជ្រុង K 25x25x0.80',
            finish: 'Mill Finish',
            brand: 'ISI K-PIPE',
            grade: 'Commercial',
            material: 'Hot-Dip Galvanized Steel',
            size: '25X25',
            thickness: 0.8,
            weight: 3.19,
            unit: 'PCS',
            price: 3.89),
        _sku(
            categoryId: kPipeCategoryId,
            materialNumber: '1400001011',
            seq: 4,
            family: 'K Pipe-GI',
            name: 'Galvanized K Pipe 25x25x0.90x6m',
            nameKh: 'ដែកទីប-ស ជ្រុង K 25x25x0.90',
            finish: 'Mill Finish',
            brand: 'ISI K-PIPE',
            grade: 'Commercial',
            material: 'Hot-Dip Galvanized Steel',
            size: '25X25',
            thickness: 0.9,
            weight: 3.683,
            unit: 'PCS',
            price: 4.49),
        _sku(
            categoryId: kPipeCategoryId,
            materialNumber: '1400001139',
            seq: 5,
            family: 'K Pipe-GI',
            name: 'Galvanized K Pipe 30x30x0.80x6m',
            nameKh: 'ដែកទីប-ស ជ្រុង K 30x30x0.80',
            finish: 'Mill Finish',
            brand: 'ISI K-PIPE',
            grade: 'Commercial',
            material: 'Hot-Dip Galvanized Steel',
            size: '30X30',
            thickness: 0.8,
            weight: 3.848,
            unit: 'PCS',
            price: 4.69),
        _sku(
            categoryId: kPipeCategoryId,
            materialNumber: '1400001050',
            seq: 6,
            family: 'K Pipe-GI',
            name: 'Galvanized K Pipe 30x30x0.90x6m',
            nameKh: 'ដែកទីប-ស ជ្រុង K 30x30x0.90',
            finish: 'Mill Finish',
            brand: 'ISI K-PIPE',
            grade: 'Commercial',
            material: 'Hot-Dip Galvanized Steel',
            size: '30X30',
            thickness: 0.9,
            weight: 4.435,
            unit: 'PCS',
            price: 5.41),
      ];

  // -- 6. GI steel sheet: Width -> Thickness -> Grade --------------------
  // Slit coil sold by width; there is no family step because the whole
  // category is one product with two dimensions.

  static List<Map<String, dynamic>> _sheet() => [
        _sku(
            categoryId: steelSheetCategoryId,
            materialNumber: '1400000859',
            seq: 1,
            family: 'GI STEEL SHEET',
            name: 'GI Steel Sheet 630x1.500x2m (SGCC-Z60)',
            nameKh: 'ដែកសន្លឺក ស 630x1.500x2m - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'GI STEEL SHEET',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '630 mm',
            thickness: 1.5,
            width: 630.0,
            weight: 13.812,
            unit: 'PCS',
            price: 16.3),
        _sku(
            categoryId: steelSheetCategoryId,
            materialNumber: '1400001256',
            seq: 2,
            family: 'GI STEEL SHEET',
            name: 'GI Steel Sheet 1250x0.80x2.41m (SGCC-Z60',
            nameKh: 'ដែកសន្លឺក ស 1250x0.80x2.41M - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'GI STEEL SHEET',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '1250 mm',
            thickness: 0.8,
            width: 1250.0,
            weight: 1.0,
            unit: 'M',
            price: 1.18),
        _sku(
            categoryId: steelSheetCategoryId,
            materialNumber: '2400000687',
            seq: 3,
            family: 'GI STEEL SHEET',
            name: 'GI Steel Sheet 47x0.80 (SGCC-Z60)',
            nameKh: 'ដែកសន្លឺក ស 47x0.80mm - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'GI STEEL SHEET',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '47 mm',
            thickness: 0.8,
            width: 47.0,
            weight: 0.29,
            unit: 'M',
            price: 0.47),
        _sku(
            categoryId: steelSheetCategoryId,
            materialNumber: '2400000689',
            seq: 4,
            family: 'GI STEEL SHEET',
            name: 'GI Steel Sheet 64x1.40 (SGCC-Z60)',
            nameKh: 'ដែកសន្លឺក ស 64x1.40mm - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'GI STEEL SHEET',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '64 mm',
            thickness: 1.4,
            width: 64.0,
            weight: 0.7,
            unit: 'M',
            price: 0.83),
        _sku(
            categoryId: steelSheetCategoryId,
            materialNumber: '2400000696',
            seq: 5,
            family: 'GI STEEL SHEET',
            name: 'GI Steel Sheet 600x0.80 (SGCC-Z60)',
            nameKh: 'ដែកសន្លឺក ស 600x0.80mm - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'GI STEEL SHEET',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '600 mm',
            thickness: 0.8,
            width: 600.0,
            weight: 3.76,
            unit: 'M',
            price: 4.44),
        _sku(
            categoryId: steelSheetCategoryId,
            materialNumber: '2400000704',
            seq: 6,
            family: 'GI STEEL SHEET',
            name: 'GI Steel Sheet 1000x1.50 (SGCC-Z180)',
            nameKh: 'ដែកសន្លឺក ស 1000x1.50mm - SGCC-Z180',
            finish: 'Mill Finish',
            brand: 'GI STEEL SHEET',
            grade: 'SGCC-Z180',
            material: 'Hot-Dip Galvanized Steel',
            size: '1000 mm',
            thickness: 1.5,
            width: 1000.0,
            weight: 11.75,
            unit: 'M',
            price: 13.86),
      ];

  // -- 7. GI steel bending: Width -> Thickness -> Grade ------------------
  // Same steel as the sheet above, already folded — priced higher for the
  // press work, which is why it is a category and not a flag.

  static List<Map<String, dynamic>> _bend() => [
        _sku(
            categoryId: sheetBendingCategoryId,
            materialNumber: '1400001254',
            seq: 1,
            family: 'GI STEEL BENDING',
            name: 'GI Steel Bending 1250x0.800 (SGCC-Z60)6M',
            nameKh: 'ដែកសន្លឹក ស 1250X0.8mm-(SGCC-Z60)6M',
            finish: 'Mill Finish',
            brand: 'GI STEEL BENDING',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '1250 mm',
            thickness: 0.8,
            width: 1250.0,
            weight: 6.851,
            unit: 'PCS',
            price: 9.73),
        _sku(
            categoryId: sheetBendingCategoryId,
            materialNumber: '2400000651',
            seq: 2,
            family: 'GI STEEL BENDING',
            name: 'GI Steel Bending 47x0.80 (SGCC-Z60)',
            nameKh: 'ដែកសន្លឺក ស 47x0.80mm - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'GI STEEL BENDING',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '47 mm',
            thickness: 0.8,
            width: 47.0,
            weight: 0.29,
            unit: 'M',
            price: 0.57),
        _sku(
            categoryId: sheetBendingCategoryId,
            materialNumber: '2400000653',
            seq: 3,
            family: 'GI STEEL BENDING',
            name: 'GI Steel Bending 64x1.40 (SGCC-Z60)',
            nameKh: 'ដែកសន្លឺក ស 64x1.40mm - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'GI STEEL BENDING',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '64 mm',
            thickness: 1.4,
            width: 64.0,
            weight: 0.7,
            unit: 'M',
            price: 0.99),
        _sku(
            categoryId: sheetBendingCategoryId,
            materialNumber: '2400000660',
            seq: 4,
            family: 'GI STEEL BENDING',
            name: 'GI Steel Bending 600x0.80 (SGCC-Z60)',
            nameKh: 'ដែកសន្លឺក ស 600x0.80mm - SGCC-Z60',
            finish: 'Mill Finish',
            brand: 'GI STEEL BENDING',
            grade: 'SGCC-Z60',
            material: 'Hot-Dip Galvanized Steel',
            size: '600 mm',
            thickness: 0.8,
            width: 600.0,
            weight: 3.76,
            unit: 'M',
            price: 5.34),
        _sku(
            categoryId: sheetBendingCategoryId,
            materialNumber: '2400000668',
            seq: 5,
            family: 'GI STEEL BENDING',
            name: 'GI Steel Bending 1000x1.50 (SGCC-Z180)',
            nameKh: 'ដែកសន្លឺក ស 1000x1.50mm - SGCC-Z180',
            finish: 'Mill Finish',
            brand: 'GI STEEL BENDING',
            grade: 'SGCC-Z180',
            material: 'Hot-Dip Galvanized Steel',
            size: '1000 mm',
            thickness: 1.5,
            width: 1000.0,
            weight: 11.75,
            unit: 'M',
            price: 16.68),
        _sku(
            categoryId: sheetBendingCategoryId,
            materialNumber: '2400000670',
            seq: 6,
            family: 'GI STEEL BENDING',
            name: 'GI Steel Bending 1020x1.50 (SGCC-Z180)',
            nameKh: 'ដែកសន្លឺក ស 1020x1.50mm - SGCC-Z180',
            finish: 'Mill Finish',
            brand: 'GI STEEL BENDING',
            grade: 'SGCC-Z180',
            material: 'Hot-Dip Galvanized Steel',
            size: '1020 mm',
            thickness: 1.5,
            width: 1020.0,
            weight: 11.98,
            unit: 'M',
            price: 17.01),
      ];

  // -- 9. Traded reinforcement: Product -> Mill -> Grade -> Diameter -----
  // Bought in and resold (MaterialType HAWA), so the mill is a real
  // buying decision the way a coating line is for roofing — Tung Ho and Hoa
  // Phat are not interchangeable to a depot with a spec to meet.

  static List<Map<String, dynamic>> _rebar() => [
        _sku(
            categoryId: reinforcementCategoryId,
            materialNumber: '1500000327',
            seq: 1,
            family: 'Deformed Bar',
            name: 'Debar B500B 12mm AS',
            nameKh: 'ដែកសរសៃ  B500B 12mm',
            finish: 'Mill Finish',
            brand: 'AS',
            grade: 'B500B',
            material: 'Hot-Rolled Carbon Steel',
            size: '12 mm',
            diameter: 12.0,
            weight: 10.662,
            unit: 'PCS',
            price: 7.89),
        _sku(
            categoryId: reinforcementCategoryId,
            materialNumber: '1500000005',
            seq: 2,
            family: 'Deformed Bar',
            name: 'Debar SD390 18mm HAI SHENG',
            nameKh: 'ដែកសរសៃ SD390-18mm',
            finish: 'Mill Finish',
            brand: 'HAI SHENG',
            grade: 'SD390',
            material: 'Hot-Rolled Carbon Steel',
            size: '18 mm',
            diameter: 18.0,
            weight: 23.989,
            unit: 'PCS',
            price: 17.75),
        _sku(
            categoryId: reinforcementCategoryId,
            materialNumber: '1500000907',
            seq: 3,
            family: 'Wire Rod',
            name: 'Wire Rod HPB300 6.5mm CHINA',
            nameKh: 'ដែកកង HPB300 6.5mm',
            finish: 'Mill Finish',
            brand: 'CHINA',
            grade: 'HPB300',
            material: 'Hot-Rolled Carbon Steel',
            size: '6.5 mm',
            diameter: 6.5,
            weight: 1.0,
            unit: 'KG',
            price: 0.74),
        _sku(
            categoryId: reinforcementCategoryId,
            materialNumber: '1500000064',
            seq: 4,
            family: 'Wire Rod',
            name: 'Wire Rod HPB300 6.5mm HDS',
            nameKh: 'ដែកកង HPB300 6.5mm',
            finish: 'Mill Finish',
            brand: 'HDS',
            grade: 'HPB300',
            material: 'Hot-Rolled Carbon Steel',
            size: '6.5 mm',
            diameter: 6.5,
            weight: 1.0,
            unit: 'KG',
            price: 0.74),
        _sku(
            categoryId: reinforcementCategoryId,
            materialNumber: '1500000868',
            seq: 5,
            family: 'Debar Coil',
            name: 'Debar Coil HRB400 10mm CHINA',
            nameKh: 'ដែកកងថ្នាំអំពៅ HRB400 10mm',
            finish: 'Mill Finish',
            brand: 'CHINA',
            grade: 'HRB400',
            material: 'Hot-Rolled Carbon Steel',
            size: '10 mm',
            diameter: 10.0,
            weight: 7.404,
            unit: 'PCS',
            price: 5.48),
        _sku(
            categoryId: reinforcementCategoryId,
            materialNumber: '1500000060',
            seq: 6,
            family: 'Debar Coil',
            name: 'Debar Coil HRB400 8mm DONGHUA',
            nameKh: 'ដែកកងថ្នាំអំពៅ HRB400 8mm',
            finish: 'Mill Finish',
            brand: 'DONGHUA',
            grade: 'HRB400',
            material: 'Hot-Rolled Carbon Steel',
            size: '8 mm',
            diameter: 8.0,
            weight: 1.0,
            unit: 'KG',
            price: 0.74),
      ];

  // -- 10. Traded beams: Section -> Size ---------------------------------
  // Also resold, all SS400 from POSCO, so grade and brand are constant
  // across the line and neither earns a step.

  static List<Map<String, dynamic>> _sections() => [
        _sku(
            categoryId: tradedSectionCategoryId,
            materialNumber: '1500000070',
            seq: 1,
            family: 'H-Beam',
            name: 'H BEAM SS400 150x150-7x10mm POSCO/SYS',
            nameKh: 'ដែក H SS400 150x150-7x10mm POSCO/SYS',
            finish: 'Mill Finish',
            brand: 'POSCO',
            grade: 'SS400',
            material: 'Structural Steel',
            size: 'H150X150',
            weight: 378.0,
            unit: 'PCS',
            price: 325.08),
        _sku(
            categoryId: tradedSectionCategoryId,
            materialNumber: '1500000071',
            seq: 2,
            family: 'H-Beam',
            name: 'H BEAM SS400 200x200-8x12mm POSCO/SYS',
            nameKh: 'ដែក H SS400 200x200-8x12mm POSCO/SYS',
            finish: 'Mill Finish',
            brand: 'POSCO',
            grade: 'SS400',
            material: 'Structural Steel',
            size: 'H200X200',
            weight: 599.0,
            unit: 'PCS',
            price: 515.14),
        _sku(
            categoryId: tradedSectionCategoryId,
            materialNumber: '1500000072',
            seq: 3,
            family: 'H-Beam',
            name: 'H BEAM SS400 250x250-9x14mm POSCO/SYS',
            nameKh: 'ដែក H SS400 250x250-9x14mm POSCO/SYS',
            finish: 'Mill Finish',
            brand: 'POSCO',
            grade: 'SS400',
            material: 'Structural Steel',
            size: 'H250X250',
            weight: 869.0,
            unit: 'PCS',
            price: 747.34),
        _sku(
            categoryId: tradedSectionCategoryId,
            materialNumber: '1500000074',
            seq: 4,
            family: 'I-Beam',
            name: 'I BEAM SS400 100x55-3x6mm',
            nameKh: 'ដែក I SS400 100x55-3x6mm',
            finish: 'Mill Finish',
            brand: 'POSCO',
            grade: 'SS400',
            material: 'Structural Steel',
            size: 'I100X55',
            weight: 47.0,
            unit: 'PCS',
            price: 40.42),
        _sku(
            categoryId: tradedSectionCategoryId,
            materialNumber: '1500000075',
            seq: 5,
            family: 'I-Beam',
            name: 'I BEAM SS400 150x75-5x7mm POSCO/SYS',
            nameKh: 'ដែក I SS400 150x75-5x7mm POSCO/SYS',
            finish: 'Mill Finish',
            brand: 'POSCO',
            grade: 'SS400',
            material: 'Structural Steel',
            size: 'I150X75',
            weight: 168.0,
            unit: 'PCS',
            price: 144.48),
        _sku(
            categoryId: tradedSectionCategoryId,
            materialNumber: '1500000076',
            seq: 6,
            family: 'I-Beam',
            name: 'I BEAM SS400 198x99-4.5x7mm POSCO/SYS',
            nameKh: 'ដែក​ I SS400 198X99-4.5x7mm POSCO/SYS',
            finish: 'Mill Finish',
            brand: 'POSCO',
            grade: 'SS400',
            material: 'Structural Steel',
            size: 'I198X99',
            weight: 218.0,
            unit: 'PCS',
            price: 187.48),
      ];

  // -- Row builder ----------------------------------------------------

  /// Builds one catalog row in the same wire shape [MockProductData] emits, so
  /// [ProductModel.fromJson] handles both without a second code path.
  ///
  /// [materialNumber] is the genuine SAP material number, so a rep who reads a
  /// number off a delivery note in the demo can search it and find the row —
  /// and so a future real-SAP sync will collide on the same key rather than
  /// duplicating the catalog.
  ///
  /// Stock is derived from [seq] rather than randomised: the demo set exists to
  /// make the flow reproducible, and a screenshot that shows different numbers
  /// on every run is a worse test artefact than one that doesn't.
  ///
  /// [length], [diameter], [thickness] and [width] default to 0, which the
  /// catalog treats as "not applicable to this product" — the facet query skips
  /// non-positive numerics, so a pipe never offers a girth picker.
  static Map<String, dynamic> _sku({
    required String categoryId,
    required String materialNumber,
    required int seq,
    required String family,
    required String name,
    required String nameKh,
    required String finish,
    required String brand,
    required String grade,
    required String material,
    required String size,
    required double weight,
    required String unit,
    required double price,
    double length = 0,
    double diameter = 0,
    double thickness = 0,
    double width = 0,
  }) {
    final code = 'M$materialNumber';
    final id = '$code-$_warehouse';
    final stock = (120 + seq * 45).toDouble();

    return {
      'id': id,
      'familyId': 'fam_${_slug(family)}',
      'familyName': family,
      'code': code,
      'sku': id,
      'materialCode': materialNumber,
      'barcode': _barcodeFor(id),
      'name': name,
      // Khmer is its own field, not a prefix glued onto the description.
      //
      // It used to be concatenated, which meant the UI could only ever render
      // both languages at once or neither — a Khmer-speaking rep got the
      // English name with Khmer stapled above it, and search could not tell
      // the two apart. Separate columns let the widget pick one and the
      // search index match both.
      'nameKh': nameKh,
      'description': '$name - $grade - $material',
      'categoryId': categoryId,
      // `subCategory` carries SAP's TopColor; `color` is the real home for it
      // now that the column exists. Both are written so the guided filter's
      // published schema (which reads `subCategory`) keeps working unchanged.
      'color': finish,
      'specification': '$size · $grade · $material',
      'subCategory': finish,
      'brand': brand,
      'grade': grade,
      'material': material,
      'size': size,
      'diameter': diameter,
      'thickness': thickness,
      'length': length,
      'width': width,
      'height': 0.0,
      'weight': weight,
      'unit': unit,
      'warehouseCode': _warehouse,
      'territory': _territory,
      'businessUnit': _businessUnit,
      'imageUrl':
          'https://picsum.photos/seed/${Uri.encodeComponent(code)}/400/300',
      'isMto': false,
      'status': 'active',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'deleted': false,
      'minStock': 50.0,
      'maxStock': 2000.0,
      'stockQuantity': stock,
      'reservedQuantity': (seq * 5).toDouble(),
      'pricing': {
        'costPrice': _round(price * 0.72),
        'standardPrice': _round(price),
        'wholesalePrice': _round(price * 0.92),
        'dealerPrice': _round(price * 0.85),
        'vipPrice': _round(price * 0.80),
        'creditPrice': _round(price * 1.03),
        'cashPrice': _round(price * 0.97),
        'currency': 'USD',
        'promotionPrice': null,
        'promotionType': null,
        'promotionLabel': null,
      },
    };
  }

  static double _round(double v) => double.parse(v.toStringAsFixed(2));

  static String _slug(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static String _barcodeFor(String id) {
    final hash =
        id.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7FFFFFFF);
    return (8810000000000 + (hash % 999999999)).toString().padLeft(13, '0');
  }
}
