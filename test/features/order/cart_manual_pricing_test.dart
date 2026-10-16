import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/pricing_status.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/usecases/add_to_cart.dart';
import 'package:steelforce/features/order/domain/usecases/clear_cart.dart';
import 'package:steelforce/features/order/domain/usecases/fetch_cart.dart';
import 'package:steelforce/features/order/domain/usecases/remove_from_cart.dart';
import 'package:steelforce/features/order/domain/usecases/replace_cart.dart';
import 'package:steelforce/features/order/domain/usecases/save_quotation.dart';
import 'package:steelforce/features/order/domain/usecases/update_cart_item.dart';
import 'package:steelforce/features/order/domain/usecases/update_quotation.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotions_mock_data.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/cart_line_binding.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/material_price_view.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_items_table.dart';
import 'package:mocktail/mocktail.dart';

class MockFetchCart extends Mock implements FetchCart {}

class MockAddToCart extends Mock implements AddToCart {}

class MockUpdateCartItem extends Mock implements UpdateCartItem {}

class MockRemoveFromCart extends Mock implements RemoveFromCart {}

class MockClearCart extends Mock implements ClearCart {}

class MockReplaceCart extends Mock implements ReplaceCart {}

class MockSaveQuotation extends Mock implements SaveQuotation {}

class MockUpdateQuotation extends Mock implements UpdateQuotation {}

Product _dummyProduct() {
  return Product(
    id: 'P1-WH01',
    familyId: 'F1',
    familyName: 'Palm Profile',
    code: 'P1',
    sku: 'SKU-001',
    materialCode: 'RF-PALM-035',
    barcode: '123456',
    name: 'Palm Profile 0.35mm',
    description: 'Palm Profile roofing',
    categoryId: 'roofing',
    subCategory: 'profile',
    brand: 'ISI Palm',
    grade: 'SGCC',
    material: 'Steel',
    size: '0.35mm',
    diameter: 0.0,
    thickness: 0.35,
    length: 6.0,
    width: 1.0,
    height: 0.0,
    weight: 15.0,
    unit: 'PC',
    warehouseCode: 'WH01',
    territory: 'Phnom Penh',
    businessUnit: 'ISI Steel',
    imageUrl: '',
    isMto: false,
    status: ProductStatus.active,
    updatedAt: DateTime.now(),
    pricing: ProductPricing.unpriced(),
    stockQuantity: 100,
    reservedQuantity: 0,
    minStock: 10,
    maxStock: 500,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(CartItem(
      id: 'fallback',
      product: _dummyProduct(),
      quantity: 1,
      unit: 'PC',
      discountPercent: 0,
    ));
  });

  group('Manual Unit Price Override', () {
    test('CartItem without override and unpriced has pending pricing', () {
      final item = CartItem(
        id: 'item_1',
        product: _dummyProduct(),
        quantity: 10,
        unit: 'PC',
        discountPercent: 0,
      );

      expect(item.pricingStatus, equals(PricingStatus.waitingForHq));
      expect(item.isPricePending, isTrue);
      expect(item.unitPriceOrNull, isNull);
      expect(item.lineTotalOrNull, isNull);
    });

    test(
        'CartItem with unitPriceOverride reflects manual USD price and calculates totals',
        () {
      final item = CartItem(
        id: 'item_1',
        product: _dummyProduct(),
        quantity: 10,
        unit: 'PC',
        discountPercent: 10, // 10% discount
        unitPriceOverride: 25.0, // $25 USD
      );

      expect(item.pricingStatus, equals(PricingStatus.available));
      expect(item.isPricePending, isFalse);
      expect(item.unitPrice, equals(25.0));
      expect(item.lineSubtotal, equals(250.0));
      expect(item.lineDiscount, equals(25.0));
      expect(item.lineTotal, equals(225.0));
    });

    test(
        'CartCubit.updateUnitPrice sets manual price override and emits updated CartLoaded',
        () async {
      final mockFetch = MockFetchCart();
      final mockUpdate = MockUpdateCartItem();
      final mockAdd = MockAddToCart();
      final mockRemove = MockRemoveFromCart();
      final mockClear = MockClearCart();
      final mockReplace = MockReplaceCart();
      final mockSave = MockSaveQuotation();
      final mockUpdateQ = MockUpdateQuotation();

      final initialItem = CartItem(
        id: 'item_1',
        product: _dummyProduct(),
        quantity: 5,
        unit: 'PC',
        discountPercent: 0,
      );

      when(() => mockFetch(any()))
          .thenAnswer((_) async => Success([initialItem]));
      when(() => mockUpdate(any()))
          .thenAnswer((_) async => const Success(null));

      final cubit = CartCubit(
        fetchCart: mockFetch,
        addToCart: mockAdd,
        updateCartItem: mockUpdate,
        removeFromCart: mockRemove,
        clearCart: mockClear,
        replaceCart: mockReplace,
        saveQuotation: mockSave,
        updateQuotation: mockUpdateQ,
      );

      await cubit.load();
      expect(cubit.state, isA<CartLoaded>());
      var loaded = cubit.state as CartLoaded;
      expect(loaded.items.first.isPricePending, isTrue);

      // Set manual unit price: $15.50 USD
      await cubit.updateUnitPrice('item_1', 15.50);

      loaded = cubit.state as CartLoaded;
      final updated = loaded.items.first;
      expect(updated.unitPriceOverride, equals(15.50));
      expect(updated.isPricePending, isFalse);
      expect(updated.unitPrice, equals(15.50));
      expect(loaded.subtotal, equals(77.50)); // 5 * 15.50
      expect(loaded.tax, equals(7.75)); // 10% VAT
      expect(loaded.total, equals(85.25)); // 77.50 + 7.75

      verify(() => mockUpdate(any())).called(1);

      // Clear manual price back to pending
      await cubit.updateUnitPrice('item_1', null);
      loaded = cubit.state as CartLoaded;
      expect(loaded.items.first.unitPriceOverride, isNull);
      expect(loaded.items.first.isPricePending, isTrue);

      await cubit.close();
    });
  });

  group('Quotation Sample Lines for Promotions', () {
    test(
        'getQuotationSampleLinesForPromo returns formatted quotation line metrics',
        () {
      final promo = mockQuotationPromoGroups.first.promos.first;
      final lines = getQuotationSampleLinesForPromo(promo);

      expect(lines.isNotEmpty, isTrue);
      final line = lines.first;
      expect(line.lineNo, equals(1));
      expect(line.materialCode, isNotEmpty);
      expect(line.quantity, greaterThan(0));
      expect(line.unitPriceUsd, greaterThan(0));
      expect(line.subtotal, equals(line.quantity * line.unitPriceUsd));
      expect(line.discountAmount,
          equals(line.subtotal * (line.discountPercent / 100)));
      expect(line.total, equals(line.subtotal - line.discountAmount));
    });
  });

  group('MaterialPriceView & Manual Price', () {
    testWidgets(
        'shows "Material doesn\'t have price" note and "Input Price (USD)" button when unpriced',
        (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: Scaffold(
              body: MaterialPriceView(
                price: const MobilePrice(
                  material: 'MAT-1',
                  state: PricingState.error,
                  errorKind: PricingErrorKind.backendUnavailable,
                ),
                onInputPrice: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Material doesn't have price"), findsOneWidget);
      expect(find.text('Input Price (USD)'), findsOneWidget);
    });

    testWidgets(
        'shows manual price with \$ and (Manual USD) badge and large font',
        (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: const Scaffold(
              body: MaterialPriceView(
                price: null,
                manualPrice: 42.50,
                unit: 'KG',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$42.50'), findsOneWidget);
      expect(find.text('/ KG'), findsOneWidget);
      expect(find.text('(Manual USD)'), findsOneWidget);
    });

    testWidgets(
        'if material already get successful price, hides manual price feature completely even if manualPrice is provided',
        (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: const Scaffold(
              body: MaterialPriceView(
                price: MobilePrice(
                  material: 'MAT-1',
                  price: 88.00,
                  currency: 'USD',
                  state: PricingState.loaded,
                ),
                manualPrice: 42.50,
                unit: 'KG',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Official backend price is displayed
      expect(find.text(r'$88.00'), findsOneWidget);
      expect(find.text('/ KG'), findsOneWidget);

      // Manual price feature is completely hidden
      expect(find.text(r'$42.50'), findsNothing);
      expect(find.text('(Manual USD)'), findsNothing);
      expect(find.text('Input Price (USD)'), findsNothing);
    });

    testWidgets(
        'allows manual price only when material cannot get price from backend',
        (tester) async {
      // 1. Error state without manual price -> shows "Material doesn't have price" & "Input Price (USD)"
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: const Scaffold(
              body: MaterialPriceView(
                price: MobilePrice(
                  material: 'MAT-1',
                  state: PricingState.error,
                  errorKind: PricingErrorKind.backendUnavailable,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Material doesn't have price"), findsOneWidget);

      // 2. Error state with manual price -> shows manual price and (Manual USD)
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: const Scaffold(
              body: MaterialPriceView(
                price: MobilePrice(
                  material: 'MAT-1',
                  state: PricingState.error,
                  errorKind: PricingErrorKind.backendUnavailable,
                ),
                manualPrice: 15.00,
                unit: 'PC',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$15.00'), findsOneWidget);
      expect(find.text('(Manual USD)'), findsOneWidget);
      expect(find.text("Material doesn't have price"), findsNothing);
    });
  });

  group('QuotationItemsTable Pricing Governance', () {
    testWidgets(
        'backend-priced line does not show edit icon and cannot be edited',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int editTaps = 0;
      final backendPricedItem = CartItem(
        id: 'item_backend',
        product: _dummyProduct(),
        quantity: 5,
        unit: 'PC',
        discountPercent: 0,
        unitPriceOverride: 50.0,
        isManualPrice: false, // Official backend price snapshot
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuotationItemsTable(
                  items: [backendPricedItem],
                  isEditable: true,
                  onEditPrice: (_) => editTaps++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$50.00'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      await tester.tap(find.text(r'$50.00'));
      await tester.pumpAndSettle();
      expect(editTaps, 0, reason: 'Backend-priced line must not be editable');
    });

    testWidgets('manual-priced line shows edit icon and can be edited',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int editTaps = 0;
      final manualPricedItem = CartItem(
        id: 'item_manual',
        product: _dummyProduct(),
        quantity: 5,
        unit: 'PC',
        discountPercent: 0,
        unitPriceOverride: 35.0,
        isManualPrice: true, // Rep-entered manual override
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuotationItemsTable(
                  items: [manualPricedItem],
                  isEditable: true,
                  onEditPrice: (_) => editTaps++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$35.00'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      await tester.tap(find.text(r'$35.00'));
      await tester.pumpAndSettle();
      expect(editTaps, 1, reason: 'Manual-priced line must be editable');
    });
  });

  group('CartLineBinding Price Resolver', () {
    test('CartLineBinding sets resolved unitPrice on addProduct', () async {
      final mockFetch = MockFetchCart();
      final mockUpdate = MockUpdateCartItem();
      final mockAdd = MockAddToCart();
      final mockRemove = MockRemoveFromCart();
      final mockClear = MockClearCart();
      final mockReplace = MockReplaceCart();
      final mockSave = MockSaveQuotation();
      final mockUpdateQ = MockUpdateQuotation();

      when(() => mockFetch(any())).thenAnswer((_) async => const Success([]));
      when(() => mockAdd(any())).thenAnswer((_) async => const Success(null));

      final cubit = CartCubit(
        fetchCart: mockFetch,
        addToCart: mockAdd,
        updateCartItem: mockUpdate,
        removeFromCart: mockRemove,
        clearCart: mockClear,
        replaceCart: mockReplace,
        saveQuotation: mockSave,
        updateQuotation: mockUpdateQ,
      );

      await cubit.load();

      final product = _dummyProduct();
      final binding = CartLineBinding(
        cart: cubit,
        priceResolver: (p) => 99.50,
      );

      final verdict = await binding.setQuantity(product, 2);
      expect(verdict.isValid, isTrue);

      // Verify that addToCart was invoked with unitPrice: 99.50
      final captured = verify(() => mockAdd(captureAny())).captured;
      expect(captured.isNotEmpty, isTrue);
      final addParams = captured.first as CartItem;
      expect(addParams.unitPrice, equals(99.50));

      await cubit.close();
    });

    test(
        'CartLineBinding.setManualPrice adds item with depotId, leadId, and isManualPrice: true',
        () async {
      final mockFetch = MockFetchCart();
      final mockUpdate = MockUpdateCartItem();
      final mockAdd = MockAddToCart();
      final mockRemove = MockRemoveFromCart();
      final mockClear = MockClearCart();
      final mockReplace = MockReplaceCart();
      final mockSave = MockSaveQuotation();
      final mockUpdateQ = MockUpdateQuotation();

      when(() => mockFetch(any())).thenAnswer((_) async => const Success([]));
      when(() => mockAdd(any())).thenAnswer((_) async => const Success(null));

      final cubit = CartCubit(
        fetchCart: mockFetch,
        addToCart: mockAdd,
        updateCartItem: mockUpdate,
        removeFromCart: mockRemove,
        clearCart: mockClear,
        replaceCart: mockReplace,
        saveQuotation: mockSave,
        updateQuotation: mockUpdateQ,
      );

      await cubit.load();

      final product = _dummyProduct();
      final binding = CartLineBinding(
        cart: cubit,
        depotId: 'cust-123',
        leadId: 'lead-456',
        priceResolver: (p) => null,
      );

      // Rep inputs manual price on product card before touching stepper
      await binding.setManualPrice(product, 25.50);

      final state = cubit.state as CartLoaded;
      expect(state.items.length, 1);
      final item = state.items.first;
      expect(item.depotId, 'cust-123');
      expect(item.leadId, 'lead-456');
      expect(item.unitPrice, 25.50);
      expect(item.unitPriceOverride, 25.50);
      expect(item.isManualPrice, isTrue);
      expect(item.quantity, 1.0);
      expect(item.isPricePending, isFalse);

      // lineFor finds this item and quantity stepper reads 1
      expect(binding.lineFor(product), isNotNull);
      expect(binding.quantityFor(product), 1);

      // Rep taps `+` on stepper to increase quantity to 2
      when(() => mockUpdate(any()))
          .thenAnswer((_) async => const Success(null));
      final verdict = await binding.setQuantity(product, 2);
      expect(verdict.isValid, isTrue);

      final updatedState = cubit.state as CartLoaded;
      expect(updatedState.items.length, 1);
      final updatedItem = updatedState.items.first;
      expect(updatedItem.quantity, 2.0);
      expect(updatedItem.unitPrice, 25.50);
      expect(updatedItem.isManualPrice, isTrue);
      expect(updatedItem.lineTotal, 51.00);
      expect(updatedState.subtotal, 51.00);

      await cubit.close();
    });

    test('CartLineBinding.setManualPrice updates existing cart item price',
        () async {
      final mockFetch = MockFetchCart();
      final mockUpdate = MockUpdateCartItem();
      final mockAdd = MockAddToCart();
      final mockRemove = MockRemoveFromCart();
      final mockClear = MockClearCart();
      final mockReplace = MockReplaceCart();
      final mockSave = MockSaveQuotation();
      final mockUpdateQ = MockUpdateQuotation();

      when(() => mockFetch(any())).thenAnswer((_) async => const Success([]));
      when(() => mockAdd(any())).thenAnswer((_) async => const Success(null));
      when(() => mockUpdate(any()))
          .thenAnswer((_) async => const Success(null));

      final cubit = CartCubit(
        fetchCart: mockFetch,
        addToCart: mockAdd,
        updateCartItem: mockUpdate,
        removeFromCart: mockRemove,
        clearCart: mockClear,
        replaceCart: mockReplace,
        saveQuotation: mockSave,
        updateQuotation: mockUpdateQ,
      );

      await cubit.load();

      final product = _dummyProduct();
      final binding = CartLineBinding(
        cart: cubit,
        depotId: 'cust-123',
        leadId: 'lead-456',
        priceResolver: (p) => null,
      );

      // 1. Rep adds 1 via stepper first (unpriced)
      await binding.setQuantity(product, 1);
      expect((cubit.state as CartLoaded).items.first.isPricePending, isTrue);

      // 2. Rep taps Input Price on product card and enters 30.00
      await binding.setManualPrice(product, 30.00);
      final item = (cubit.state as CartLoaded).items.first;
      expect(item.unitPrice, 30.00);
      expect(item.unitPriceOverride, 30.00);
      expect(item.isManualPrice, isTrue);
      expect(item.isPricePending, isFalse);
      expect(item.lineTotal, 30.00);

      await cubit.close();
    });
  });
}
