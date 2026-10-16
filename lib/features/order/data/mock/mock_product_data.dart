import 'dart:math';

import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';

/// Deterministic generator for the demo product catalog.
///
/// Produces plain JSON-ready maps (not domain entities) — its only job is to
/// build the payload written to `assets/mock/products.json` by
/// `tool/generate_mock_products.dart`, and to act as
/// `MockProductRemoteDataSource`'s in-memory fallback if that asset is ever
/// missing.
///
/// ## What this generates, and why it isn't roofing
///
/// [IsiDemoCatalog] covers the ten manufactured and traded steel lines with
/// six hand-picked real SKUs each — enough to walk every branch of every
/// filter schema by hand, not enough to page. This generator covers the
/// *other* half of what a rep sells: the **traded catalog**, SAP MaterialType
/// `HAWA`, 1,155 distinct materials in the `SAP_BP_Data.pbix` extract —
/// Schneider switchgear, cable, gypsum and fibre-cement board, skylight
/// sheet, roofing screws and general site consumables.
///
/// Two rules follow from that split and both matter:
///
/// 1. **The category ids here never collide with [IsiDemoCatalog]'s.** Facet
///    options are `SELECT DISTINCT` aggregates scoped to a category, so a
///    single generated row landing in `cat_isi_palm_profile` would inject
///    invented gauges into the guided flow and destroy the "six SKUs, walkable
///    by hand" property the demo catalog exists to provide.
/// 2. **MRO stock is deliberately excluded.** The blank-`ProductGroup` half of
///    the material master also holds ~8,000 `ERSA`/`HIBE`/`HIB1` rows —
///    bearings, pneumatics, PPE, welding gas, safety shoes. Those are plant
///    maintenance stores, not sales stock. A rep's catalog should not be able
///    to quote a depot a pair of size-39 safety boots, so they are not
///    modelled here at all.
///
/// ## Real vocabulary, generated combinatorics
///
/// Every brand, series, rating, cross-section and sheet size below is read off
/// the real material master. What is *generated* is the cross product: SAP
/// stocks 70 Draka cable materials, this emits every plausible
/// core-count x cross-section combination, because the point of the bulk
/// catalog is paging and query performance, not inventory accuracy. Embedding
/// 1,155 verbatim rows would bloat the source file for no test value; the
/// hand-picked verbatim rows live in [IsiDemoCatalog] where they earn their
/// place.
///
/// Composed from small single-purpose generators, mirroring how a real ERP
/// catalog is actually assembled — [ProductGenerator] crosses category leaves
/// x series x brand into ~300 non-sellable "families" (e.g. "Schneider Easy9
/// MCB"), [VariantGenerator] expands each family into its sellable
/// ratings/sizes, [WarehouseGenerator] assigns each SKU to a handful of
/// warehouses to land at ~11,000 rows, [PricingGenerator] derives every price
/// tier from a base price,
/// and [PromotionGenerator] decides which rows carry a promotion. Swapping any
/// one of these for a smarter version (or a real SAP-fed pipeline) doesn't
/// touch the others.
class MockProductData {
  MockProductData._();

  static Map<String, dynamic> generate({int seed = 7}) {
    final rand = Random(seed);
    final families = ProductGenerator.buildFamilies();
    final warehouses = WarehouseGenerator.warehouses;

    final products = <Map<String, dynamic>>[];
    var materialSeq = 1;

    for (final family in families) {
      final variants = VariantGenerator.buildVariants(family);
      for (final variant in variants) {
        final code = '${family.codePrefix}-${variant.sizeLabel}';
        final materialCode = 'MAT-${materialSeq.toString().padLeft(6, '0')}';
        materialSeq++;
        final assignedWarehouses =
            WarehouseGenerator.assignFor(warehouses, rand);

        for (final wh in assignedWarehouses) {
          final id = '$code-${wh.code}';
          final pricing = PricingGenerator.forVariant(family, variant, rand);
          final promo = PromotionGenerator.maybeApply(pricing, rand);
          final stockQty = (50 + rand.nextInt(2950)).toDouble();
          final reserved = stockQty * (rand.nextDouble() * 0.15);
          final daysAgo = rand.nextInt(60);

          products.add({
            'id': id,
            'familyId': family.familyId,
            'familyName': family.familyName,
            'code': code,
            'sku': id,
            'materialCode': materialCode,
            'barcode': _barcodeFor(id),
            'name': '${family.namePrefix} ${variant.sizeLabel}',
            // Same record, both languages — never a second dataset. The size
            // label (`3P 63A`, `1Cx2.5mm2`) and the brand are deliberately not
            // translated: they are SAP vocabulary a rep reads identically in
            // either language, and "translating" them would make the Khmer
            // catalog un-searchable by part number.
            'nameKh': '${family.namePrefixKh} ${variant.sizeLabel}',
            'description':
                '${family.namePrefix} ${variant.sizeLabel}, ${family.grade}, '
                    '${family.brand}, ${family.material}.',
            'categoryId': family.categoryId,
            'subCategory': family.grade,
            'brand': family.brand,
            'grade': family.grade,
            'material': family.material,
            'size': variant.sizeLabel,
            'diameter': variant.diameter,
            'thickness': variant.thickness,
            'length': variant.length,
            'width': variant.width,
            'height': variant.height,
            'weight': variant.weight,
            'unit': family.unit,
            'warehouseCode': wh.code,
            'territory': wh.province,
            'businessUnit': family.businessUnit,
            'imageUrl':
                'https://picsum.photos/seed/${Uri.encodeComponent(code)}/400/300',
            'isMto': family.isMtoEligible && variant.mtoHint,
            'status': _statusFor(rand),
            'updatedAt': DateTime.now()
                .subtract(Duration(days: daysAgo))
                .toIso8601String(),
            'deleted': false,
            'minStock': 50.0,
            'maxStock': 3000.0,
            'stockQuantity': double.parse(stockQty.toStringAsFixed(0)),
            'reservedQuantity': double.parse(reserved.toStringAsFixed(0)),
            'pricing': {
              'costPrice': pricing.costPrice,
              'standardPrice': pricing.standardPrice,
              'wholesalePrice': pricing.wholesalePrice,
              'dealerPrice': pricing.dealerPrice,
              'vipPrice': pricing.vipPrice,
              'creditPrice': pricing.creditPrice,
              'cashPrice': pricing.cashPrice,
              'currency': 'USD',
              'promotionPrice': promo?.promotionPrice,
              'promotionType': promo?.type.name,
              'promotionLabel': promo?.label,
            },
          });
        }
      }
    }

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      // The hand-written ISI demo lines lead, so the guided configurator opens
      // on them; the generated trading catalog follows and still exercises the
      // paging/performance paths.
      'categories': [
        ...IsiDemoCatalog.categories(),
        ...CategoryGenerator.categories,
      ],
      'products': [...IsiDemoCatalog.products(), ...products],
    };
  }

  static String _barcodeFor(String id) {
    final hash =
        id.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7FFFFFFF);
    return (8800000000000 + (hash % 999999999)).toString().padLeft(13, '0');
  }

  static String _statusFor(Random rand) {
    final roll = rand.nextDouble();
    if (roll < 0.93) return 'active';
    if (roll < 0.98) return 'inactive';
    return 'discontinued';
  }
}

/// Category taxonomy for the traded catalog, grouped the way SAP's
/// `MaterialGroupName` groups it: electrical distribution, cable, boards,
/// roofing trade items and general site supply.
///
/// Ids are namespaced `cat_trade_*` so they can never collide with
/// [IsiDemoCatalog]'s `cat_isi_*` — see the note on this file's class doc for
/// why that separation is load-bearing rather than cosmetic.
class CategoryGenerator {
  CategoryGenerator._();

  static final List<Map<String, dynamic>> categories = [
    {
      'id': 'cat_trade_electrical',
      'parentId': null,
      'name': 'Electrical Distribution',
      'nameKh': 'ចែកចាយអគ្គិសនី',
      'sortOrder': 0
    },
    {
      'id': 'cat_trade_mcb',
      'parentId': 'cat_trade_electrical',
      'name': 'Miniature Circuit Breakers',
      'nameKh': 'ប្រដាប់កាត់ចរន្តតូច',
      'sortOrder': 0
    },
    {
      'id': 'cat_trade_mccb',
      'parentId': 'cat_trade_electrical',
      'name': 'Moulded Case Circuit Breakers',
      'nameKh': 'ប្រដាប់កាត់ចរន្ត MCCB',
      'sortOrder': 1
    },
    {
      'id': 'cat_trade_rccb',
      'parentId': 'cat_trade_electrical',
      'name': 'Residual Current Devices',
      'nameKh': 'ឧបករណ៍ការពារចរន្តលេច',
      'sortOrder': 2
    },
    {
      'id': 'cat_trade_contactor',
      'parentId': 'cat_trade_electrical',
      'name': 'Contactors & Overload Relays',
      'nameKh': 'កុងតាក់ទ័រ និងរីឡេការពារ',
      'sortOrder': 3
    },
    {
      'id': 'cat_trade_cable',
      'parentId': null,
      'name': 'Cable',
      'nameKh': 'ខ្សែភ្លើង',
      'sortOrder': 1
    },
    {
      'id': 'cat_trade_cable_pvc',
      'parentId': 'cat_trade_cable',
      'name': 'PVC Insulated',
      'nameKh': 'អ៊ីសូឡង់ PVC',
      'sortOrder': 0
    },
    {
      'id': 'cat_trade_cable_xlpe',
      'parentId': 'cat_trade_cable',
      'name': 'XLPE Insulated',
      'nameKh': 'អ៊ីសូឡង់ XLPE',
      'sortOrder': 1
    },
    {
      'id': 'cat_trade_cable_bare',
      'parentId': 'cat_trade_cable',
      'name': 'Bare Conductor',
      'nameKh': 'ខ្សែចរន្តអាក្រាត',
      'sortOrder': 2
    },
    {
      'id': 'cat_trade_board',
      'parentId': null,
      'name': 'Boards & Ceiling',
      'nameKh': 'ផ្ទាំង និងពិដាន',
      'sortOrder': 2
    },
    {
      'id': 'cat_trade_board_gypsum',
      'parentId': 'cat_trade_board',
      'name': 'Gypsum Board',
      'nameKh': 'ផ្ទាំងជីប',
      'sortOrder': 0
    },
    {
      'id': 'cat_trade_board_fibre',
      'parentId': 'cat_trade_board',
      'name': 'Fibre Cement Board',
      'nameKh': 'ផ្ទាំងស៊ីម៉ងត៍ហ្វីប',
      'sortOrder': 1
    },
    {
      'id': 'cat_trade_board_plank',
      'parentId': 'cat_trade_board',
      'name': 'Plank & Ceiling',
      'nameKh': 'ផ្ទាំងក្តារ និងពិដាន',
      'sortOrder': 2
    },
    {
      'id': 'cat_trade_roofing',
      'parentId': null,
      'name': 'Roofing Trade Items',
      'nameKh': 'ទំនិញដំបូល',
      'sortOrder': 3
    },
    {
      'id': 'cat_trade_skylight',
      'parentId': 'cat_trade_roofing',
      'name': 'Skylight & Translucent',
      'nameKh': 'សន្លឹកពន្លឺ',
      'sortOrder': 0
    },
    {
      'id': 'cat_trade_screws',
      'parentId': 'cat_trade_roofing',
      'name': 'Screws & Fixings',
      'nameKh': 'វីស និងគ្រឿងភ្ជាប់',
      'sortOrder': 1
    },
    {
      'id': 'cat_trade_general',
      'parentId': null,
      'name': 'General Trading',
      'nameKh': 'ទំនិញទូទៅ',
      'sortOrder': 4
    },
    {
      'id': 'cat_trade_plate',
      'parentId': 'cat_trade_general',
      'name': 'Steel Plate',
      'nameKh': 'ផ្ទាំងដែក',
      'sortOrder': 0
    },
    {
      'id': 'cat_trade_chemical',
      'parentId': 'cat_trade_general',
      'name': 'Paint & Chemical',
      'nameKh': 'ថ្នាំលាប និងគីមី',
      'sortOrder': 1
    },
    {
      'id': 'cat_trade_anchor',
      'parentId': 'cat_trade_general',
      'name': 'Anchors & Adhesives',
      'nameKh': 'ប៊ូឡុងបោះ និងកាវ',
      'sortOrder': 2
    },
  ];
}

class ProductFamily {
  const ProductFamily({
    required this.familyId,
    required this.familyName,
    required this.codePrefix,
    required this.categoryId,
    required this.leafKey,
    required this.namePrefix,
    required this.namePrefixKh,
    required this.grade,
    required this.brand,
    required this.material,
    required this.unit,
    required this.businessUnit,
    required this.basePrice,
    required this.isMtoEligible,
  });

  final String familyId;
  final String familyName;
  final String codePrefix;
  final String categoryId;
  final String leafKey;
  final String namePrefix;

  /// Khmer counterpart of [namePrefix], carried on the *same* family rather
  /// than in a parallel Khmer catalog. Khmer puts the item type before the
  /// brand ("ខ្សែភ្លើង ស្ពាន់/PVC Draka"), which is why this is a whole
  /// prefix and not a word-for-word swap of [namePrefix].
  final String namePrefixKh;

  final String grade;
  final String brand;
  final String material;
  final String unit;
  final String businessUnit;
  final double basePrice;
  final bool isMtoEligible;
}

class _LeafSpec {
  const _LeafSpec({
    required this.key,
    required this.categoryId,
    required this.namePrefix,
    required this.namePrefixKh,
    required this.grades,
    required this.brands,
    required this.material,
    required this.unit,
    required this.businessUnit,
    required this.basePrice,
    this.isMtoEligible = false,
  });

  final String key;
  final String categoryId;
  final String namePrefix;

  /// Khmer for [namePrefix]. Written by a Khmer speaker against the trade
  /// vocabulary a Cambodian hardware buyer actually uses at the counter — a
  /// machine translation of "MCCB" or "Self Drilling Screw" produces a phrase
  /// no rep would say and no depot would recognise, which is worse than
  /// leaving the row in English.
  final String namePrefixKh;

  /// The series or spec a depot picks between. For traded goods this is
  /// rarely a metallurgical grade — it is a breaking capacity, a voltage
  /// rating or a board type — but it lands on the same `grade` column, which
  /// is what lets one `ProductFilter` serve both halves of the catalog.
  final List<String> grades;

  /// Real supplying brands for *this* leaf. Deliberately per-leaf rather than
  /// one global list: Gyproc does not make contactors, and a global cross
  /// would emit thousands of rows no rep would believe.
  final List<String> brands;

  final String material;
  final String unit;
  final String businessUnit;
  final double basePrice;
  final bool isMtoEligible;
}

/// Crosses each category leaf's series list with that leaf's real brands to
/// produce the traded catalog's base product families.
class ProductGenerator {
  ProductGenerator._();

  static const _leaves = <_LeafSpec>[
    // ── Electrical distribution (SAP MaterialGroupName "Schneider") ──
    _LeafSpec(
        key: 'mcb',
        categoryId: 'cat_trade_mcb',
        namePrefix: 'MCB',
        namePrefixKh: 'ប្រដាប់កាត់ចរន្តតូច',
        grades: ['C-Curve 6kA', 'C-Curve 10kA', 'B-Curve 6kA', 'D-Curve 10kA'],
        brands: ['Schneider Easy9', 'Schneider Acti9', 'Schneider Domae'],
        material: 'Thermoplastic',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 9.5),
    _LeafSpec(
        key: 'mccb',
        categoryId: 'cat_trade_mccb',
        namePrefix: 'MCCB',
        namePrefixKh: 'ប្រដាប់កាត់ចរន្ត MCCB',
        grades: ['25kA', '36kA', '50kA'],
        brands: ['Schneider EasyPact', 'Schneider ComPact'],
        material: 'Thermoplastic',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 120.0),
    _LeafSpec(
        key: 'rccb',
        categoryId: 'cat_trade_rccb',
        namePrefix: 'RCCB',
        namePrefixKh: 'ឧបករណ៍ការពារចរន្តលេច',
        grades: ['30mA AC-Type', '100mA AC-Type', '300mA AC-Type'],
        brands: ['Schneider Easy9', 'Schneider Acti9'],
        material: 'Thermoplastic',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 38.0),
    _LeafSpec(
        key: 'contactor',
        categoryId: 'cat_trade_contactor',
        namePrefix: 'Contactor',
        namePrefixKh: 'កុងតាក់ទ័រ',
        grades: ['AC-3 220VAC', 'AC-3 380VAC', 'AC-3 24VDC'],
        brands: ['Schneider TeSys D', 'Schneider TeSys Daca'],
        material: 'Thermoplastic',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 42.0),

    // ── Cable (SAP "Cable-Draka" / "Cable-Cadivi" / "Cable-STP") ──
    _LeafSpec(
        key: 'cablePvc',
        categoryId: 'cat_trade_cable_pvc',
        namePrefix: 'Cu/PVC Cable',
        namePrefixKh: 'ខ្សែភ្លើង ស្ពាន់/PVC',
        grades: ['450/750V', '0.6/1kV'],
        brands: ['Draka', 'CADIVI', 'Sento', 'LS', 'Thipha'],
        material: 'Copper / PVC',
        unit: 'M',
        businessUnit: 'Trading',
        basePrice: 1.35),
    _LeafSpec(
        key: 'cableXlpe',
        categoryId: 'cat_trade_cable_xlpe',
        namePrefix: 'Cu/XLPE/PVC Cable',
        namePrefixKh: 'ខ្សែភ្លើង ស្ពាន់/XLPE/PVC',
        grades: ['0.6/1kV', '0.6/1kV FR', '0.6/1kV LSHF'],
        brands: ['Draka', 'CADIVI', 'Sento', 'LS'],
        material: 'Copper / XLPE',
        unit: 'M',
        businessUnit: 'Trading',
        basePrice: 1.85),
    _LeafSpec(
        key: 'cableBare',
        categoryId: 'cat_trade_cable_bare',
        namePrefix: 'Bare Copper Conductor',
        namePrefixKh: 'ខ្សែស្ពាន់អាក្រាត',
        grades: ['Annealed', 'Hard Drawn'],
        brands: ['CADIVI', 'Thipha'],
        material: 'Copper',
        unit: 'M',
        businessUnit: 'Trading',
        basePrice: 2.4),

    // ── Boards (SAP "Board-Gyproc" / "Board-Shera" / "Board-Other") ──
    _LeafSpec(
        key: 'gypsum',
        categoryId: 'cat_trade_board_gypsum',
        namePrefix: 'Gypsum Board',
        namePrefixKh: 'ផ្ទាំងជីប',
        grades: ['Standard TE', 'Moisture Resistant', 'Fire Rated'],
        brands: ['Gyproc', 'Zeit', 'APLUS', 'Tam Duraflex'],
        material: 'Gypsum',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 7.2),
    _LeafSpec(
        key: 'fibreBoard',
        categoryId: 'cat_trade_board_fibre',
        namePrefix: 'Fibre Cement Board',
        namePrefixKh: 'ផ្ទាំងស៊ីម៉ងត៍ហ្វីប',
        grades: ['SE Smooth', 'Square Edge', 'Recessed Edge'],
        brands: ['Shera', 'APLUS', 'MC Board'],
        material: 'Fibre Cement',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 11.5),
    _LeafSpec(
        key: 'plank',
        categoryId: 'cat_trade_board_plank',
        namePrefix: 'Ceiling Plank',
        namePrefixKh: 'ក្តារពិដាន',
        grades: ['Vent Classic', 'Deco Texture', 'Teak Cherry'],
        brands: ['Shera', 'MC Board'],
        material: 'Fibre Cement',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 9.0),

    // ── Roofing trade items (SAP "Transparent Roofing" / "Roofing Screws") ──
    _LeafSpec(
        key: 'skylight',
        categoryId: 'cat_trade_skylight',
        namePrefix: 'Skylight Sheet',
        namePrefixKh: 'សន្លឹកពន្លឺ',
        grades: ['Opal', 'Clear', 'Tinted'],
        brands: ['Natalite', 'NAACO'],
        material: 'Polycarbonate',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 16.0,
        isMtoEligible: true),
    _LeafSpec(
        key: 'screw',
        categoryId: 'cat_trade_screws',
        namePrefix: 'Self Drilling Screw',
        namePrefixKh: 'វីសខួងខ្លួនឯង',
        grades: ['ZN-EPDM', 'YP-PVC', 'Painted Head'],
        brands: ['ISI', 'Trading-Others'],
        material: 'Zinc Plated Steel',
        unit: 'PAC',
        businessUnit: 'Trading',
        basePrice: 4.1),

    // ── General trading (SAP "Trading-Others") ──
    _LeafSpec(
        key: 'plate',
        categoryId: 'cat_trade_plate',
        namePrefix: 'Steel Plate',
        namePrefixKh: 'ផ្ទាំងដែក',
        grades: ['Q345B', 'Q235B', 'A36'],
        brands: ['Trading-Others', 'ISI'],
        material: 'Carbon Steel',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 210.0,
        isMtoEligible: true),
    _LeafSpec(
        key: 'chemical',
        categoryId: 'cat_trade_chemical',
        namePrefix: 'Metal Paint',
        namePrefixKh: 'ថ្នាំលាបដែក',
        grades: ['Primer ZP', 'Top Coat', 'Thinner'],
        brands: ['Metal Lux', 'Trading-Others'],
        material: 'Alkyd',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 12.0),
    _LeafSpec(
        key: 'anchor',
        categoryId: 'cat_trade_anchor',
        namePrefix: 'Chemical Anchor',
        namePrefixKh: 'ប៊ូឡុងបោះគីមី',
        grades: ['HIT-RE Injectable', 'Mixing Nozzle', 'Threaded Rod'],
        brands: ['Hilti', 'Trading-Others'],
        material: 'Epoxy',
        unit: 'PCS',
        businessUnit: 'Trading',
        basePrice: 18.0),
  ];

  /// Union of every leaf's brand list. Kept for callers that want "all brands
  /// in the generated catalog" without knowing the leaf structure.
  static List<String> get brands {
    final all = <String>{};
    for (final leaf in _leaves) {
      all.addAll(leaf.brands);
    }
    return all.toList()..sort();
  }

  static List<ProductFamily> buildFamilies() {
    final families = <ProductFamily>[];
    for (final leaf in _leaves) {
      for (final grade in leaf.grades) {
        for (final brand in leaf.brands) {
          final gradeSlug = grade.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
          final brandSlug = brand.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
          families.add(ProductFamily(
            familyId: 'fam_${leaf.key}_${gradeSlug}_$brandSlug',
            familyName: '$brand ${leaf.namePrefix} $grade',
            codePrefix: '${leaf.key.toUpperCase()}-$gradeSlug-$brandSlug',
            categoryId: leaf.categoryId,
            leafKey: leaf.key,
            namePrefix: '$brand ${leaf.namePrefix}',
            // Khmer leads with the item type and trails the brand — the order
            // a Cambodian counter clerk says it in. English is the reverse.
            // Same underlying family either way; only the rendering differs.
            namePrefixKh: '${leaf.namePrefixKh} $brand',
            grade: grade,
            brand: brand,
            material: leaf.material,
            unit: leaf.unit,
            businessUnit: leaf.businessUnit,
            basePrice: leaf.basePrice,
            isMtoEligible: leaf.isMtoEligible,
          ));
        }
      }
    }
    return families;
  }
}

class VariantSpec {
  const VariantSpec({
    required this.sizeLabel,
    required this.diameter,
    required this.thickness,
    required this.length,
    required this.width,
    required this.height,
    required this.weight,
    this.mtoHint = false,
  });

  final String sizeLabel;
  final double diameter;
  final double thickness;
  final double length;
  final double width;
  final double height;
  final double weight;
  final bool mtoHint;
}

/// Expands one family into its sellable SKUs. Ratings and dimensions are
/// series-independent (a 63A breaker is a 63A breaker whether it is Easy9 or
/// Acti9), so this only needs to branch on [ProductFamily.leafKey].
///
/// Numeric columns are populated only where the attribute is physically
/// meaningful — a circuit breaker has no thickness, a cable has no width. The
/// facet query skips non-positive numerics, so a breaker category never offers
/// a thickness picker.
class VariantGenerator {
  VariantGenerator._();

  static List<VariantSpec> buildVariants(ProductFamily family) {
    return switch (family.leafKey) {
      'mcb' => _mcb(),
      'mccb' => _mccb(),
      'rccb' => _rccb(),
      'contactor' => _contactor(),
      'cablePvc' || 'cableXlpe' => _cable(),
      'cableBare' => _bareConductor(),
      'gypsum' || 'fibreBoard' => _board(),
      'plank' => _plank(),
      'skylight' => _skylight(),
      'screw' => _screw(),
      'plate' => _plate(),
      'chemical' => _chemical(),
      'anchor' => _anchor(),
      _ => const [],
    };
  }

  /// Pole count x amp rating, both off the real Schneider range in the
  /// material master (EZ9F… part numbers encode exactly this pair).
  static List<VariantSpec> _mcb() {
    const poles = [1, 2, 3, 4];
    // Easy9/Domae stop at 63A, Acti9 runs to 125A; the union is what the
    // branch counter actually stocks.
    const amps = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125];
    return [
      for (final p in poles)
        for (final a in amps)
          VariantSpec(
            sizeLabel: '${p}P ${a}A',
            diameter: 0,
            thickness: 0,
            length: 0,
            width: 0,
            height: 0,
            weight: 0.12 * p,
          ),
    ];
  }

  static List<VariantSpec> _mccb() {
    const poles = [3, 4];
    const amps = [100, 125, 160, 200, 250, 320, 400, 630];
    return [
      for (final p in poles)
        for (final a in amps)
          VariantSpec(
            sizeLabel: '${p}P ${a}A',
            diameter: 0,
            thickness: 0,
            length: 0,
            width: 0,
            height: 0,
            weight: 1.4 + a / 400,
          ),
    ];
  }

  static List<VariantSpec> _rccb() {
    const poles = [2, 4];
    const amps = [25, 40, 63, 80, 100];
    return [
      for (final p in poles)
        for (final a in amps)
          VariantSpec(
            sizeLabel: '${p}P ${a}A',
            diameter: 0,
            thickness: 0,
            length: 0,
            width: 0,
            height: 0,
            weight: 0.2 * p,
          ),
    ];
  }

  static List<VariantSpec> _contactor() {
    const amps = [9, 12, 18, 25, 32, 38, 50, 65, 80, 95];
    return [
      for (final a in amps)
        VariantSpec(
          sizeLabel: '3P ${a}A',
          diameter: 0,
          thickness: 0,
          length: 0,
          width: 0,
          height: 0,
          weight: 0.35 + a / 100,
        ),
    ];
  }

  /// Core count x nominal cross-section, in the `1Cx2.5mm2` notation the real
  /// descriptions use. Cross-sections are the full IEC preferred series that
  /// appears across the Draka/CADIVI/Sento rows.
  static List<VariantSpec> _cable() {
    const cores = [1, 2, 3, 4];
    // IEC 60228 preferred series, the full run that appears across the
    // Draka / CADIVI / Sento rows.
    // Every entry must be a double literal: one bare `4` makes this a
    // List<num> and VariantSpec's double parameters stop accepting it.
    const areas = <double>[
      0.75,
      1.0,
      1.5,
      2.5,
      4.0,
      6.0,
      10.0,
      16.0,
      25.0,
      35.0,
      50.0,
      70.0,
      95.0,
      120.0,
      150.0,
      185.0,
      240.0,
      300.0,
    ];
    return [
      for (final c in cores)
        for (final a in areas)
          VariantSpec(
            sizeLabel: '${c}Cx${_trim(a)}mm2',
            diameter: 0,
            // Nominal conductor area has no column of its own, so it rides on
            // `thickness` — the only spare numeric facet — which is why the
            // cable categories label that step "Cross-section", not
            // "Thickness". See the note in the class doc.
            thickness: a,
            length: 0,
            width: 0,
            height: 0,
            weight: c * a * 0.0105,
          ),
    ];
  }

  static List<VariantSpec> _bareConductor() {
    const areas = <double>[
      16.0,
      25.0,
      35.0,
      50.0,
      70.0,
      95.0,
      120.0,
      150.0,
      185.0,
      240.0,
      300.0,
    ];
    return [
      for (final a in areas)
        VariantSpec(
          sizeLabel: '${_trim(a)}mm2',
          diameter: 0,
          thickness: a,
          length: 0,
          width: 0,
          height: 0,
          weight: a * 0.0092,
        ),
    ];
  }

  /// Thickness x sheet size. Both lists are the real ones: 1200x2400 and
  /// 1220x2440 both appear in the master because the suppliers disagree.
  static List<VariantSpec> _board() {
    const thicknesses = <double>[4.0, 6.0, 8.0, 9.0, 12.0, 15.0, 18.0];
    const sheets = <List<double>>[
      [1200.0, 2400.0],
      [1220.0, 2440.0],
      [600.0, 1200.0],
    ];
    return [
      for (final t in thicknesses)
        for (final s in sheets)
          VariantSpec(
            sizeLabel: '${_trim(t)}x${_trim(s[0])}x${_trim(s[1])}',
            diameter: 0,
            thickness: t,
            length: s[1] / 1000,
            width: s[0],
            height: 0,
            weight: t * s[0] * s[1] / 1000000 * 0.9,
          ),
    ];
  }

  static List<VariantSpec> _plank() {
    const thicknesses = <double>[4.0, 6.0, 8.0];
    const planks = <List<double>>[
      [200.0, 4000.0],
      [300.0, 3000.0],
      [600.0, 1200.0],
    ];
    return [
      for (final t in thicknesses)
        for (final p in planks)
          VariantSpec(
            sizeLabel: '${_trim(t)}x${_trim(p[0])}x${_trim(p[1])}',
            diameter: 0,
            thickness: t,
            length: p[1] / 1000,
            width: p[0],
            height: 0,
            weight: t * p[0] * p[1] / 1000000 * 1.1,
          ),
    ];
  }

  /// Matches the Palm Profile roofing pitches so a skylight sheet can be
  /// ordered to drop into the same run — 980 and 1000-7 are the real ones.
  static List<VariantSpec> _skylight() {
    const profiles = ['PalmCap 980', 'Trim 1000-7', 'Trim 1000-5', 'Wave 950'];
    const thicknesses = <double>[0.8, 1.0, 1.2, 1.5, 2.0];
    const lengths = <double>[2.0, 3.0, 4.0, 6.0];
    return [
      for (final p in profiles)
        for (final t in thicknesses)
          for (final l in lengths)
            VariantSpec(
              sizeLabel: '$p ${_trim(t)}mm x ${_trim(l)}m',
              diameter: 0,
              thickness: t,
              length: l,
              width: 980,
              height: 0,
              weight: t * l * 1.35,
              mtoHint: l >= 6,
            ),
    ];
  }

  static List<VariantSpec> _screw() {
    const gauges = [10, 12, 14];
    const lengths = <double>[1.0, 1.5, 2.0, 2.5, 3.0, 4.0];
    return [
      for (final g in gauges)
        for (final l in lengths)
          VariantSpec(
            sizeLabel: '#$g x ${_trim(l)}"',
            diameter: g / 2,
            thickness: 0,
            length: l * 0.0254,
            width: 0,
            height: 0,
            weight: 0.9 + l * 0.4,
          ),
    ];
  }

  static List<VariantSpec> _plate() {
    const thicknesses = <double>[
      3.0,
      4.0,
      5.0,
      6.0,
      8.0,
      10.0,
      12.0,
      16.0,
      20.0,
      25.0,
    ];
    const sheets = <List<double>>[
      [1500.0, 6000.0],
      [2000.0, 6000.0],
    ];
    return [
      for (final t in thicknesses)
        for (final s in sheets)
          VariantSpec(
            sizeLabel: '${_trim(t)}x${_trim(s[0])}x${_trim(s[1])}',
            diameter: 0,
            thickness: t,
            length: s[1] / 1000,
            width: s[0],
            height: 0,
            weight: t * s[0] * s[1] / 1000000 * 7.85,
            mtoHint: t >= 16,
          ),
    ];
  }

  static List<VariantSpec> _chemical() {
    const packs = ['0.8L', '3L', '5L', '18L', '20L'];
    return [
      for (final p in packs)
        VariantSpec(
          sizeLabel: p,
          diameter: 0,
          thickness: 0,
          length: 0,
          width: 0,
          height: 0,
          weight: double.parse(p.replaceAll(RegExp(r'[^0-9.]'), '')) * 1.1,
        ),
    ];
  }

  static List<VariantSpec> _anchor() {
    const sizes = ['M8', 'M10', 'M12', 'M16', 'M20', '330ml', '500ml'];
    return [
      for (final s in sizes)
        VariantSpec(
          sizeLabel: s,
          diameter: 0,
          thickness: 0,
          length: 0,
          width: 0,
          height: 0,
          weight: 0.6,
        ),
    ];
  }

  /// "2.5" not "2.5000000001", "4" not "4.0" — variant labels end up in
  /// product codes and barcodes, so they have to be stable and terse.
  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class Warehouse {
  const Warehouse(this.code, this.province);
  final String code;
  final String province;
}

/// Warehouse network + which SKUs stock where — every SKU is assigned to a
/// small subset (2-4 of 8), not all warehouses, matching how real branches
/// only carry a slice of the catalog and keeping the dataset in the spec'd
/// 10k-30k row range instead of exploding by full warehouse count.
///
/// The spread is 2-4 rather than the 1-3 the steel catalog used because the
/// traded range is narrower: ~3.7k distinct codes against the old ~7k, so a
/// lower multiplier would drop the catalog under the row count the paging and
/// scroll-performance tests are calibrated against.
class WarehouseGenerator {
  WarehouseGenerator._();

  static final List<Warehouse> warehouses = [
    const Warehouse('WH-PP01', 'Phnom Penh'),
    const Warehouse('WH-PP02', 'Phnom Penh'),
    const Warehouse('WH-SR01', 'Siem Reap'),
    const Warehouse('WH-BTB01', 'Battambang'),
    const Warehouse('WH-KPC01', 'Kampong Cham'),
    const Warehouse('WH-SHV01', 'Sihanoukville'),
    const Warehouse('WH-KAN01', 'Kandal'),
    const Warehouse('WH-KAM01', 'Kampot'),
  ];

  static List<Warehouse> assignFor(List<Warehouse> all, Random rand) {
    final count = 2 + rand.nextInt(3);
    final shuffled = List<Warehouse>.from(all)..shuffle(rand);
    return shuffled.take(count).toList();
  }
}

class VariantPricing {
  const VariantPricing({
    required this.costPrice,
    required this.standardPrice,
    required this.wholesalePrice,
    required this.dealerPrice,
    required this.vipPrice,
    required this.creditPrice,
    required this.cashPrice,
  });

  final double costPrice;
  final double standardPrice;
  final double wholesalePrice;
  final double dealerPrice;
  final double vipPrice;
  final double creditPrice;
  final double cashPrice;
}

/// Derives every price tier from one base price. Standard carries the
/// nominal margin over cost; the other tiers are consistent discounts/
/// markups off standard, matching how real depot price groups work.
///
/// Unchanged from the steel catalog this file used to generate, and it still
/// behaves: on traded goods with no meaningful dimensions (a breaker, a tin of
/// primer) `sizeFactor` collapses to 1 and the leaf's `basePrice` carries the
/// whole value, which is why those base prices are set per item rather than
/// per kilo.
class PricingGenerator {
  PricingGenerator._();

  static VariantPricing forVariant(
      ProductFamily family, VariantSpec variant, Random rand) {
    final sizeFactor = 1 +
        (variant.diameter + variant.thickness) * 0.02 +
        variant.length * 0.05;
    final jitter = 0.95 + rand.nextDouble() * 0.10;
    final standard = double.parse(
        (family.basePrice * sizeFactor * jitter).toStringAsFixed(2));
    final cost = double.parse((standard * 0.72).toStringAsFixed(2));

    return VariantPricing(
      costPrice: cost,
      standardPrice: standard,
      wholesalePrice: double.parse((standard * 0.92).toStringAsFixed(2)),
      dealerPrice: double.parse((standard * 0.85).toStringAsFixed(2)),
      vipPrice: double.parse((standard * 0.80).toStringAsFixed(2)),
      creditPrice: double.parse((standard * 1.03).toStringAsFixed(2)),
      cashPrice: double.parse((standard * 0.97).toStringAsFixed(2)),
    );
  }
}

class AppliedPromotion {
  const AppliedPromotion(
      {required this.type, required this.label, required this.promotionPrice});
  final PromotionType type;
  final String label;
  final double promotionPrice;
}

/// Mirrors the domain `PromotionType` enum member-for-member. [ProductModel]
/// parses this back with `PromotionType.values.byName(...)`, which throws on
/// an unknown name — so adding a member here without adding it to the domain
/// enum breaks catalog parsing at sync time, not at compile time. Change both
/// or neither.
enum PromotionType { percentDiscount, buyXGetY, clearance, monthly }

/// Decides which rows carry a promotion (~15%) and what it looks like.
class PromotionGenerator {
  PromotionGenerator._();

  static AppliedPromotion? maybeApply(VariantPricing pricing, Random rand) {
    if (rand.nextDouble() > 0.15) return null;

    final type =
        PromotionType.values[rand.nextInt(PromotionType.values.length)];
    return switch (type) {
      PromotionType.percentDiscount => AppliedPromotion(
          type: type,
          label: '${(5 + rand.nextInt(16))}% Off',
          promotionPrice: double.parse(
              (pricing.standardPrice * (0.95 - rand.nextInt(16) / 100))
                  .toStringAsFixed(2)),
        ),
      PromotionType.buyXGetY => AppliedPromotion(
          type: type,
          label: 'Buy 10 Get 1',
          promotionPrice:
              double.parse((pricing.standardPrice * 0.91).toStringAsFixed(2)),
        ),
      PromotionType.clearance => AppliedPromotion(
          type: type,
          label: 'Clearance Sale',
          promotionPrice:
              double.parse((pricing.standardPrice * 0.75).toStringAsFixed(2)),
        ),
      PromotionType.monthly => AppliedPromotion(
          type: type,
          label: 'Monthly Promotion',
          promotionPrice:
              double.parse((pricing.standardPrice * 0.90).toStringAsFixed(2)),
        ),
    };
  }
}
