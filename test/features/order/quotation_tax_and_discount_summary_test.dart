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
import 'package:steelforce/features/order/pdf/quotation_pdf_data.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/discount_summary_section.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_preview_section.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/shipment_widget_section.dart';

Product _testProduct({
  String id = 'prod-1',
  String sku = 'SKU-001',
  String name = 'Product A',
  String materialCode = 'MAT-001',
  double price = 100.0,
}) =>
    Product(
      id: id,
      familyId: 'fam-1',
      familyName: 'Structural',
      code: sku,
      sku: sku,
      materialCode: materialCode,
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
      size: '1.2mm',
      diameter: 0,
      thickness: 1.2,
      length: 6.0,
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
        costPrice: 80,
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

CartItem _testCartItem({
  required String id,
  required Product product,
  double quantity = 10,
  double discountPercent = 0,
  double unitPrice = 100.0,
}) =>
    CartItem(
      id: id,
      product: product,
      quantity: quantity,
      unit: 'pcs',
      discountPercent: discountPercent,
      unitPriceOverride: unitPrice,
    );

Widget _wrap(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  group('Tax Section in ShipmentSelectionWidget', () {
    testWidgets(
        'renders Tax section under COD with Tax Invoice and Commercial Invoice options',
        (tester) async {
      bool? selectedTax;

      await tester.pumpWidget(_wrap(
        ShipmentSelectionWidget(
          method: ShipmentMethod.pickup,
          pickupLocation: PickupLocation.factory,
          deliveryOption: null,
          isCod: false,
          isTaxApplicable: true,
          onMethodChanged: (_) {},
          onPickupLocationChanged: (_) {},
          onDeliveryOptionChanged: (_) {},
          onCodChanged: (_) {},
          onTaxApplicableChanged: (val) => selectedTax = val,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify COD Section exists
      expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      // Verify Type of Invoice Section exists directly under COD
      expect(find.text('Type of Invoice'), findsOneWidget);
      expect(find.text('Tax Invoice'), findsOneWidget);
      expect(find.text('Commercial Invoice'), findsOneWidget);

      // Tap Commercial Invoice
      await tester.tap(find.text('Commercial Invoice'));
      expect(selectedTax, isFalse);

      // Tap Tax Invoice
      await tester.tap(find.text('Tax Invoice'));
      expect(selectedTax, isTrue);
    });

    testWidgets(
        'shows active selection for Commercial Invoice when isTaxApplicable is false',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ShipmentSelectionWidget(
          method: ShipmentMethod.pickup,
          pickupLocation: PickupLocation.factory,
          deliveryOption: null,
          isCod: false,
          isTaxApplicable: false,
          onMethodChanged: (_) {},
          onPickupLocationChanged: (_) {},
          onDeliveryOptionChanged: (_) {},
          onCodChanged: (_) {},
          onTaxApplicableChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tax Invoice'), findsOneWidget);
      expect(find.text('Commercial Invoice'), findsOneWidget);
    });
  });

  group('DiscountSummarySection', () {
    testWidgets(
        'renders Invoice Discounts and SKU Discounts with separated free units',
        (tester) async {
      final p1 =
          _testProduct(id: 'p1', sku: 'SKU-001', name: 'Product A', price: 100);
      final p2 =
          _testProduct(id: 'p2', sku: 'SKU-002', name: 'Product B', price: 50);

      // p1 has 3% discount (3% of $1000 = $30.00)
      final item1 = _testCartItem(
          id: 'item1',
          product: p1,
          quantity: 10,
          discountPercent: 3,
          unitPrice: 100);
      // p2 has 0% monetary discount, but 50 units might qualify for free goods promotion
      final item2 = _testCartItem(
          id: 'item2',
          product: p2,
          quantity: 50,
          discountPercent: 0,
          unitPrice: 50);

      final invoiceDiscounts = [
        const InvoiceDiscountItem(
          name: 'Summer Promotion',
          rule: '3%',
          amount: 3.00,
        ),
        const InvoiceDiscountItem(
          name: 'Special Offer',
          rule: '\$1.00',
          amount: 1.00,
        ),
      ];

      await tester.pumpWidget(_wrap(
        DiscountSummarySection(
          items: [item1, item2],
          invoiceDiscounts: invoiceDiscounts,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Discount Summary'), findsOneWidget);

      // Verify Invoice Discounts section
      expect(find.text('Invoice Discounts'), findsOneWidget);
      expect(find.textContaining('Summer Promotion'), findsOneWidget);
      expect(find.textContaining('Special Offer'), findsOneWidget);
      expect(find.textContaining('-\$3.00'), findsWidgets);
      expect(find.textContaining('-\$1.00'), findsWidgets);

      // Verify SKU Discounts section
      expect(find.text('SKU Discounts'), findsOneWidget);
      expect(find.textContaining('Product A / SKU-001'), findsOneWidget);
      expect(find.textContaining('3%'), findsWidgets);

      // Verify Total Discount row
      expect(find.text('Total Discount'), findsOneWidget);
    });

    testWidgets('displays None under sections when no discounts exist',
        (tester) async {
      final p1 =
          _testProduct(id: 'p1', sku: 'SKU-001', name: 'Product A', price: 100);
      // No discount percent, small quantity below free goods rungs
      final item1 = _testCartItem(
          id: 'item1',
          product: p1,
          quantity: 1,
          discountPercent: 0,
          unitPrice: 100);

      await tester.pumpWidget(_wrap(
        DiscountSummarySection(
          items: [item1],
          invoiceDiscounts: const [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Discount Summary'), findsOneWidget);
      expect(find.text('Invoice Discounts'), findsOneWidget);
      expect(find.text('SKU Discounts'), findsOneWidget);
      // Both sections show None
      expect(find.text('None'), findsNWidgets(2));
      expect(find.text('\$0.00'), findsOneWidget);
    });
  });

  group('QuotationPreviewSection Tax Display', () {
    testWidgets('shows (10%) when isTaxApplicable is true', (tester) async {
      final p1 =
          _testProduct(id: 'p1', sku: 'SKU-001', name: 'Product A', price: 100);
      final item1 = _testCartItem(
          id: 'item1',
          product: p1,
          quantity: 1,
          discountPercent: 0,
          unitPrice: 100);

      await tester.pumpWidget(_wrap(
        QuotationPreviewSection(
          subtotal: 100,
          discount: 0,
          tax: 10,
          total: 110,
          items: [item1],
          isTaxApplicable: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('(10%)'), findsOneWidget);
      expect(find.text('Exempt'), findsNothing);
    });

    testWidgets('shows Exempt badge and 0 tax when isTaxApplicable is false',
        (tester) async {
      final p1 =
          _testProduct(id: 'p1', sku: 'SKU-001', name: 'Product A', price: 100);
      final item1 = _testCartItem(
          id: 'item1',
          product: p1,
          quantity: 1,
          discountPercent: 0,
          unitPrice: 100);

      await tester.pumpWidget(_wrap(
        QuotationPreviewSection(
          subtotal: 100,
          discount: 0,
          tax: 0,
          total: 100,
          items: [item1],
          isTaxApplicable: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Exempt'), findsOneWidget);
      expect(find.text('(10%)'), findsNothing);
    });
  });

  group('QuotationPdfData mapping', () {
    test('populates isTaxApplicable, invoiceDiscounts, and promotion lines',
        () {
      final p1 =
          _testProduct(id: 'p1', sku: 'SKU-001', name: 'Product A', price: 100);
      final item1 = _testCartItem(
          id: 'item1',
          product: p1,
          quantity: 10,
          discountPercent: 5,
          unitPrice: 100);

      final pdfData = QuotationPdfData.fromCart(
        quotationNumber: 'QT-20260911-001',
        depotName: 'Test Depot',
        salesRepName: 'John Rep',
        createdDate: DateTime(2026, 9, 11),
        items: [item1],
        subtotal: 1000,
        discount: 50,
        tax: 0,
        total: 950,
        isTaxApplicable: false,
        invoiceDiscounts: ['Summer Promotion (3%): -\$3.00'],
      );

      expect(pdfData.isTaxApplicable, isFalse);
      expect(pdfData.tax, equals(0));
      expect(pdfData.invoiceDiscounts.length, equals(1));
      expect(pdfData.invoiceDiscounts.first, contains('Summer Promotion'));
      expect(pdfData.lines.length, equals(1));
      expect(pdfData.lines.first.sku, equals('SKU-001'));
      expect(pdfData.lines.first.discountPercent, equals(5));
      expect(pdfData.lines.first.discountAmount, equals(50));
      expect(pdfData.lines.first.discountText, contains('5% / -\$50.00'));
    });

    test(
        'supports dedicated SKU Discount column data formatting and summary distinction',
        () {
      // Product A: 2 units @ $10.00, 3% discount -> $0.60 discount, amount $19.40
      final p1 = _testProduct(
          id: 'p1', sku: 'SKU-001', name: 'Product A', price: 10.0);
      final item1 = _testCartItem(
          id: 'item1',
          product: p1,
          quantity: 2,
          discountPercent: 3,
          unitPrice: 10.0);

      // Product B: 1 unit @ $20.00, 0% monetary discount, amount $20.00
      final p2 = _testProduct(
          id: 'p2', sku: 'SKU-002', name: 'Product B', price: 20.0);
      final item2 = _testCartItem(
          id: 'item2',
          product: p2,
          quantity: 1,
          discountPercent: 0,
          unitPrice: 20.0);

      final pdfData = QuotationPdfData.fromCart(
        quotationNumber: 'QT-20260911-002',
        depotName: 'Depot Test',
        salesRepName: 'Sales Rep',
        createdDate: DateTime(2026, 9, 11),
        items: [item1, item2],
        subtotal: 40.0,
        discount:
            2.60, // Total discount ($0.60 SKU discount + $2.00 invoice discount)
        tax: 0,
        total: 37.40,
        isTaxApplicable: false,
        invoiceDiscounts: ['COD / Pickup Discount (5%): -\$2.00'],
      );

      // Check line items SKU discount column values
      expect(pdfData.lines.length, equals(2));

      final line1 = pdfData.lines[0];
      expect(line1.sku, equals('SKU-001'));
      expect(line1.name, equals('Product A'));
      expect(line1.quantity, equals(2));
      expect(line1.unitPrice, equals(10.0));
      expect(line1.discountAmount, equals(0.60));
      expect(line1.discountText, contains('3% / -\$0.60'));
      expect(line1.lineTotal, equals(19.40));

      final line2 = pdfData.lines[1];
      expect(line2.sku, equals('SKU-002'));
      expect(line2.name, equals('Product B'));
      expect(line2.quantity, equals(1));
      expect(line2.unitPrice, equals(20.0));
      expect(line2.discountAmount, equals(0.0));
      // Products without discounts should show '—'
      expect(line2.discountText, equals('—'));
      expect(line2.lineTotal, equals(20.0));

      // Check Invoice Summary breakdown
      expect(pdfData.subtotal, equals(40.0));
      expect(pdfData.skuDiscountTotal, equals(0.60));
      expect(pdfData.invoiceDiscountTotal, equals(2.00));
      expect(pdfData.totalDiscount,
          equals(2.60)); // Total = SKU ($0.60) + Invoice ($2.00)
    });
  });
}
