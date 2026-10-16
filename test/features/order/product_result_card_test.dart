import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_card.dart';

/// The material selection card's contract, after selection was made
/// independent of stock and pricing.
///
/// What it must show is identification. What it must **not** show is a stock
/// band or an amount — and, more importantly, neither may prevent the rep from
/// adding the material. The card used to do all three, so these are regression
/// tests rather than descriptions.
Product _product({
  double stockQuantity = 0,
  double reservedQuantity = 0,
  ProductStatus status = ProductStatus.active,
  bool stockKnown = true,
  bool isBlocked = false,
  ProductPricing pricing = const ProductPricing(
    costPrice: 8,
    standardPrice: 11.59,
    wholesalePrice: 11,
    dealerPrice: 10.5,
    vipPrice: 10,
    creditPrice: 12,
    cashPrice: 11,
    currency: 'USD',
  ),
}) =>
    Product(
      id: 'p1',
      familyId: 'f1',
      familyName: 'Roofing',
      code: 'C1',
      sku: 'SKU1',
      materialCode: 'MAT-1',
      barcode: '000',
      name: 'Colour Coated Coil',
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
      status: status,
      isBlocked: isBlocked,
      updatedAt: DateTime(2026, 1, 1),
      pricing: pricing,
      stockQuantity: stockQuantity,
      reservedQuantity: reservedQuantity,
      minStock: 0,
      maxStock: 1000,
      stockKnown: stockKnown,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  late int? changedTo;

  Future<void> pump(WidgetTester tester, Product product,
      {int quantity = 0}) async {
    changedTo = null;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: Scaffold(
            body: ProductResultCard(
              product: product,
              isFavorite: false,
              quantity: quantity,
              onQuantityChanged: (v) => changedTo = v,
              onToggleFavorite: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The stepper shows the new number immediately and debounces the write, so
  /// a test asserting the callback has to wait out the debounce.
  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  }

  group('shows identification', () {
    testWidgets('the material name', (tester) async {
      await pump(tester, _product());
      expect(find.text('Colour Coated Coil'), findsOneWidget);
    });

    testWidgets('the group and the unit', (tester) async {
      await pump(tester, _product());
      expect(find.text('Roofing · sheet'), findsOneWidget);
    });
  });

  group('shows no stock', () {
    testWidgets('no band for a product with nothing on hand', (tester) async {
      // The old card printed "Out of stock" here and dimmed the `+`.
      await pump(tester, _product(stockQuantity: 0));
      expect(find.text('Out of stock'), findsNothing);
      expect(find.text('No stock'), findsNothing);
    });

    testWidgets('no band for a product with plenty on hand', (tester) async {
      await pump(tester, _product(stockQuantity: 500));
      expect(find.text('High stock'), findsNothing);
      expect(find.text('In stock'), findsNothing);
      expect(find.text('Low stock'), findsNothing);
    });

    testWidgets('no band when the figure is unknown', (tester) async {
      await pump(tester, _product(stockKnown: false));
      expect(find.textContaining('stock'), findsNothing);
    });
  });

  group('shows no price', () {
    testWidgets('no amount for a priced material', (tester) async {
      await pump(tester, _product());
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('no placeholder for an unpriced material', (tester) async {
      await pump(tester, _product(pricing: const ProductPricing.unpriced()));
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.textContaining('0.00'), findsNothing);
    });
  });

  group('never blocks selection', () {
    testWidgets('nothing on hand still adds', (tester) async {
      await pump(tester, _product(stockQuantity: 0));
      await tapAdd(tester);
      expect(changedTo, 1);
    });

    testWidgets('an unknown stock figure still adds', (tester) async {
      // The exact case that broke in the field: a material from the selection
      // API, whose `availableQuantity` is 0 because the API never sent one.
      await pump(tester, _product(stockKnown: false));
      await tapAdd(tester);
      expect(changedTo, 1);
    });

    testWidgets('an unpriced material still adds', (tester) async {
      await pump(tester, _product(pricing: const ProductPricing.unpriced()));
      await tapAdd(tester);
      expect(changedTo, 1);
    });

    testWidgets('an inactive product still adds', (tester) async {
      // Selection is independent of what SAP currently says. A blocked or
      // inactive material is settled later in the workflow, not by refusing
      // the tap.
      await pump(tester, _product(status: ProductStatus.inactive));
      await tapAdd(tester);
      expect(changedTo, 1);
    });
  });
}
