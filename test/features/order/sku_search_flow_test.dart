import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/sku_search_card.dart';

Product _testProduct({
  String id = 'p1',
  String sku = '10002345',
  String name = 'GI PIPE 1.2mm x 6M',
  String familyName = 'GI Pipe',
  String size = '1.2mm x 6M',
  String unit = 'PCS',
}) =>
    Product(
      id: id,
      familyId: 'f1',
      familyName: familyName,
      code: sku,
      sku: sku,
      materialCode: sku,
      barcode: '000',
      name: name,
      description: '',
      color: '',
      specification: '',
      categoryId: 'cat1',
      subCategory: 'sub',
      brand: 'ISI',
      grade: 'G1',
      material: 'Steel',
      size: size,
      diameter: 0,
      thickness: 1.2,
      length: 6.0,
      width: 0,
      height: 0,
      weight: 10,
      unit: unit,
      warehouseCode: 'WH-PP01',
      territory: 'T1',
      businessUnit: 'BU1',
      imageUrl: '',
      isMto: false,
      status: ProductStatus.active,
      isBlocked: false,
      updatedAt: DateTime(2026, 1, 1),
      pricing: const ProductPricing(
        costPrice: 8,
        standardPrice: 11.59,
        wholesalePrice: 11,
        dealerPrice: 10.5,
        vipPrice: 10,
        creditPrice: 12,
        cashPrice: 11,
        currency: 'USD',
      ),
      stockQuantity: 100,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 500,
    );

Widget _wrap(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  group('SkuSearchCard', () {
    testWidgets('renders SKU, product name, and family/unit details',
        (tester) async {
      final product = _testProduct(
        sku: '10002345',
        name: 'GI PIPE 1.2mm x 6M',
        familyName: 'GI Pipe',
      );

      await tester.pumpWidget(_wrap(
        SkuSearchCard(
          product: product,
          isSelected: false,
          onTap: () {},
        ),
      ));

      expect(find.text('SKU: 10002345'), findsOneWidget);
      expect(find.text('GI PIPE 1.2mm x 6M'), findsOneWidget);
      expect(find.textContaining('GI Pipe'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('shows active checkmark icon when isSelected is true',
        (tester) async {
      final product = _testProduct(sku: '10002346');

      await tester.pumpWidget(_wrap(
        SkuSearchCard(
          product: product,
          isSelected: true,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('fires onTap callback when tapped', (tester) async {
      var tapped = false;
      final product = _testProduct(sku: '10002347');

      await tester.pumpWidget(_wrap(
        SkuSearchCard(
          product: product,
          isSelected: false,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(SkuSearchCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('ProductFilterFlowState selectedSku and selectedProduct', () {
    test('selectedProduct resolves the matching product by sku', () {
      final p1 = _testProduct(id: 'p1', sku: 'SKU-001');
      final p2 = _testProduct(id: 'p2', sku: 'SKU-002');

      const stateNoSelection = ProductFilterFlowState(
        products: [],
        selectedSku: null,
      );
      expect(stateNoSelection.selectedProduct, isNull);

      final stateWithSelection = ProductFilterFlowState(
        products: [p1, p2],
        selectedSku: 'SKU-002',
      );
      expect(stateWithSelection.selectedProduct, equals(p2));
    });

    test('copyWith allows setting and resetting selectedSku', () {
      final p1 = _testProduct(id: 'p1', sku: 'SKU-001');
      var state = ProductFilterFlowState(
        products: [p1],
        selectedSku: 'SKU-001',
      );
      expect(state.selectedSku, 'SKU-001');

      // Reset to null
      state = state.copyWith(selectedSku: () => null);
      expect(state.selectedSku, isNull);
      expect(state.selectedProduct, isNull);
    });
  });
}
