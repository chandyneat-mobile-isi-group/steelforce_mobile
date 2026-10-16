import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/entities/sales_order_status.dart';
import 'package:steelforce/features/order/presentation/screens/sales_order/sales_order_detail_screen.dart';

Product _product({String name = 'Colour Coated Coil', String nameKh = ''}) =>
    Product(
      id: 'p1',
      familyId: 'f1',
      familyName: 'Roofing',
      code: 'C1',
      sku: 'SKU-1',
      materialCode: 'MAT-1',
      barcode: '000',
      name: name,
      nameKh: nameKh,
      description: '',
      color: 'Blue',
      specification: '',
      categoryId: 'cat1',
      subCategory: 'sub',
      brand: 'ISI',
      grade: 'G1',
      material: 'Steel',
      size: '1219mm',
      diameter: 0,
      thickness: 0.3,
      length: 3.9,
      width: 1.219,
      height: 0,
      weight: 10,
      unit: 'sheet',
      warehouseCode: 'WH1',
      territory: 'T1',
      businessUnit: 'BU1',
      imageUrl: '',
      isMto: false,
      status: ProductStatus.active,
      updatedAt: DateTime(2026, 1, 1),
      pricing: const ProductPricing(
        costPrice: 8,
        standardPrice: 10,
        wholesalePrice: 10,
        dealerPrice: 10,
        vipPrice: 10,
        creditPrice: 10,
        cashPrice: 10,
        currency: 'USD',
      ),
      stockQuantity: 100,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 1000,
    );

CartItem _line({String id = 'l1', double quantity = 3, Product? product}) =>
    CartItem(
      id: id,
      product: product ?? _product(),
      quantity: quantity,
      unit: 'sheet',
      discountPercent: 0,
    );

SalesOrder _order({
  SalesOrderStatus status = SalesOrderStatus.confirmed,
  List<CartItem> lines = const [],
  String? shopName = 'Phnom Penh Steel Outlet',
  String? leadDisplayName,
  double discount = 0,
}) =>
    SalesOrder(
      id: 'SO-100294',
      quotationId: 'QT-5512',
      lines: lines,
      subtotal: 30,
      discount: discount,
      tax: 3,
      total: 33,
      status: status,
      sapStatus: 'CREATED',
      createdAt: DateTime(2026, 8, 20, 14, 30),
      shopName: shopName,
      leadDisplayName: leadDisplayName,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mirrors `AppBootstrapService`: the explicit-locale `DateFormat`
    // constructors this screen uses throw without it.
    await initializeDateFormatting();
    await LocalizationService.instance.load('en');
  });

  Future<void> pump(
    WidgetTester tester,
    SalesOrder order, {
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: SalesOrderDetailScreen(order: order),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the order identity, party and status', (tester) async {
    await pump(tester, _order());

    expect(find.text('SO-100294'), findsOneWidget);
    expect(find.text('Phnom Penh Steel Outlet'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('renders every line with its computed line total',
      (tester) async {
    await pump(
      tester,
      _order(lines: [_line(id: 'l1'), _line(id: 'l2', quantity: 2)]),
    );

    expect(find.text('Colour Coated Coil'), findsNWidgets(2));
    // 3 × $10 and 2 × $10 — the line total is derived, never stored, so this
    // is the assertion that would catch a wrong price tier reaching the UI.
    expect(find.text(r'$30.00'), findsWidgets);
    expect(find.text(r'$20.00'), findsOneWidget);
  });

  testWidgets('falls back to the lead name when there is no shop',
      (tester) async {
    await pump(
        tester, _order(shopName: null, leadDisplayName: 'Sok Dara (lead)'));

    expect(find.text('Sok Dara (lead)'), findsOneWidget);
  });

  testWidgets('names the missing party rather than leaving a blank line',
      (tester) async {
    await pump(tester, _order(shopName: null, leadDisplayName: null));

    // A silent gap here reads as a rendering bug rather than absent data.
    expect(find.text('No depot on record'), findsOneWidget);
  });

  testWidgets('hides the discount row when there is no discount',
      (tester) async {
    await pump(tester, _order());
    expect(find.text('Discount'), findsNothing);

    await pump(tester, _order(discount: 5));
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text(r'−$5.00'), findsOneWidget);
  });

  testWidgets('an order with no lines says so instead of rendering nothing',
      (tester) async {
    await pump(tester, _order());

    expect(find.text('This order has no line items.'), findsOneWidget);
  });

  testWidgets('a pending order is distinguishable by text, not colour alone',
      (tester) async {
    await pump(tester, _order(status: SalesOrderStatus.pending));

    // FS-A11Y-3: amber vs green is exactly the pair a colour-blind rep cannot
    // separate, so the word has to be there too.
    expect(find.text('Pending'), findsOneWidget);
  });

  group('layout', () {
    testWidgets('does not overflow at 200% text scale', (tester) async {
      // FS-A11Y-2. Any RenderFlex overflow raises through the test binding.
      await pump(tester, _order(lines: [_line()]), textScale: 2.0);

      expect(tester.takeException(), isNull);
    });

    for (final size in const [
      Size(390, 844), // phone
      Size(834, 1112), // tablet portrait
      Size(1366, 1024), // tablet landscape
    ]) {
      testWidgets('lays out at ${size.width.toInt()}pt without overflow',
          (tester) async {
        await pump(tester, _order(lines: [_line()]), size: size);

        expect(tester.takeException(), isNull);
        expect(find.text('SO-100294'), findsOneWidget);
      });
    }
  });

  group('in Khmer', () {
    // Loaded in setUp, not the test body: `load` goes through `rootBundle` and
    // real I/O awaited inside `testWidgets` never completes against the fake
    // clock.
    setUp(() => LocalizationService.instance.load('km'));
    tearDown(() => LocalizationService.instance.load('en'));

    testWidgets('renders Khmer copy with no missing-key leakage',
        (tester) async {
      await pump(tester, _order(lines: [_line()]));

      expect(find.text('បានបញ្ជាក់'), findsOneWidget); // Confirmed
      expect(find.text('សរុបការបញ្ជាទិញ'), findsOneWidget); // Order total

      // FS-LOC-1/2: an untranslated key renders as the raw dotted path. None
      // may reach the screen in either language.
      final leaked = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((s) => RegExp(r'^orders\.[a-z_.]+$').hasMatch(s))
          .toList();
      expect(leaked, isEmpty, reason: 'untranslated keys reached the UI');
    });

    testWidgets('Khmer does not overflow at 200% text scale', (tester) async {
      // FS-LOC-4 — Khmer renders taller than Latin and does not break on
      // spaces, so it is the language that finds a fixed-height box.
      await pump(tester, _order(lines: [_line()]), textScale: 2.0);

      expect(tester.takeException(), isNull);
    });
  });
}
