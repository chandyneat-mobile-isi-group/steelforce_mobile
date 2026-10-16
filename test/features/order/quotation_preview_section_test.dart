import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_preview_section.dart';

Product _product({double price = 100}) => Product(
      id: 'p1',
      familyId: 'f1',
      familyName: 'Roofing',
      code: 'C-1',
      sku: 'SKU-1',
      materialCode: 'MAT-1',
      barcode: '000',
      name: 'Coil',
      description: '',
      color: '',
      specification: '',
      categoryId: 'cat1',
      subCategory: 'sub',
      brand: 'ISI',
      grade: 'G1',
      material: 'Steel',
      size: '1.2mm',
      diameter: 0,
      thickness: 1.2,
      length: 6,
      width: 0,
      height: 0,
      weight: 10,
      unit: 'pcs',
      warehouseCode: 'WH-01',
      territory: 'T1',
      businessUnit: 'BU1',
      imageUrl: '',
      isMto: false,
      status: ProductStatus.active,
      isBlocked: false,
      updatedAt: DateTime(2026, 1, 1),
      pricing: ProductPricing(
        costPrice: 0,
        standardPrice: price,
        wholesalePrice: price,
        dealerPrice: price,
        vipPrice: price,
        creditPrice: price,
        cashPrice: price,
        currency: 'USD',
      ),
      stockQuantity: 1000,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 5000,
    );

CartItem _item({double? unitPrice = 100}) => CartItem(
      id: 'item1',
      product: _product(price: unitPrice ?? 0),
      quantity: 1,
      unit: 'pcs',
      discountPercent: 0,
      unitPriceOverride: unitPrice,
    );

const _agreement = DepotAgreement(
  id: 'ag1',
  category: 'Roofing',
  percent: 5,
  kind: 'standing',
  status: 'active',
);

Widget _wrap(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

QuotationPreviewSection _section({
  String? shopName,
  List<CartItem>? items,
  bool isEstimate = false,
  int requiredApprovalLevel = 0,
  List<QuotationWarning> warnings = const [],
  List<DepotAgreement> agreements = const [],
  VoidCallback? onEnlargeTap,
  void Function(CartItem)? onEditPrice,
}) =>
    QuotationPreviewSection(
      shopName: shopName,
      subtotal: 123.45,
      discount: 0,
      tax: 12.34,
      total: 135.79,
      items: items ?? [_item()],
      isEstimate: isEstimate,
      requiredApprovalLevel: requiredApprovalLevel,
      warnings: warnings,
      agreements: agreements,
      onEnlargeTap: onEnlargeTap,
      onEditPrice: onEditPrice,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    // The items table overflows on a pending line; that layout is not what
    // these tests pin.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(child));
    await tester.pumpAndSettle();
  }

  group('header', () {
    testWidgets('names a walk-in when there is no shop', (tester) async {
      await pump(tester, _section());

      expect(find.text('orders.quotation.builder_title'.tr), findsOneWidget);
      expect(
        find.text(
          '${'orders.quotation_extra.walk_in'.tr} · '
          '${'orders.quotation_extra.today'.tr}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('names the shop when one is given', (tester) async {
      await pump(tester, _section(shopName: 'Sokha Steel'));

      expect(
        find.text('Sokha Steel · ${'orders.quotation_extra.today'.tr}'),
        findsOneWidget,
      );
    });

    testWidgets('enlarge shows only with a callback, and calls it',
        (tester) async {
      await pump(tester, _section());
      expect(find.text('orders.quotation_extra.enlarge'.tr), findsNothing);

      var taps = 0;
      await pump(tester, _section(onEnlargeTap: () => taps++));
      await tester.tap(find.text('orders.quotation_extra.enlarge'.tr));
      expect(taps, 1);
    });
  });

  group('status chips', () {
    testWidgets('auto-approved and no estimate by default', (tester) async {
      await pump(tester, _section());

      expect(find.text('Auto-Approved'), findsOneWidget);
      expect(find.text('Estimate (SAP Offline)'), findsNothing);
    });

    testWidgets('estimate and approval level when the server asks',
        (tester) async {
      await pump(tester, _section(isEstimate: true, requiredApprovalLevel: 2));

      expect(find.text('Estimate (SAP Offline)'), findsOneWidget);
      expect(find.text('Level 2 Approval Required'), findsOneWidget);
      expect(find.text('Auto-Approved'), findsNothing);
    });
  });

  group('notices', () {
    testWidgets('lists agreements and warnings, falling back to the code',
        (tester) async {
      await pump(
        tester,
        _section(
          agreements: const [_agreement],
          warnings: const [
            QuotationWarning(code: 'CREDIT', message: 'Over credit limit'),
            QuotationWarning(code: 'NO_STOCK'),
          ],
        ),
      );

      expect(find.text('Agreement: 5.0% (Roofing)'), findsOneWidget);
      expect(find.text('Over credit limit'), findsOneWidget);
      expect(find.text('NO_STOCK'), findsOneWidget);
    });

    testWidgets('shows neither when there are none', (tester) async {
      await pump(tester, _section());

      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('totals', () {
    testWidgets('shows the server amounts for a priced quotation',
        (tester) async {
      await pump(tester, _section());

      expect(find.text('\$123.45'), findsOneWidget);
      expect(find.text('\$12.34'), findsOneWidget);
      expect(find.text('\$135.79'), findsOneWidget);
      expect(find.text('orders.quotation_extra.quote_disclaimer'.tr),
          findsOneWidget);
    });

    testWidgets('hides every amount while a line is pending', (tester) async {
      await pump(tester, _section(items: [_item(unitPrice: 0)]));

      expect(find.text('\$123.45'), findsNothing);
      expect(find.text('\$12.34'), findsNothing);
      expect(find.text('\$135.79'), findsNothing);
    });
  });

  group('edit price', () {
    testWidgets('routes a pending line to the given callback', (tester) async {
      CartItem? edited;
      await pump(
        tester,
        _section(items: [_item(unitPrice: 0)], onEditPrice: (i) => edited = i),
      );

      await tester.tap(find.text('Input Price (USD)'));
      await tester.pumpAndSettle();

      expect(edited?.id, 'item1');
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('opens the manual price sheet without a callback',
        (tester) async {
      await pump(tester, _section(items: [_item(unitPrice: 0)]));

      await tester.tap(find.text('Input Price (USD)'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
