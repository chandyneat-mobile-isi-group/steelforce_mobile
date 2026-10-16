import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/fetch_favorites.dart';
import 'package:steelforce/features/order/domain/usecases/toggle_favorite.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/manual_price_book.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_state.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_totals.dart';
import 'package:steelforce/features/order/presentation/widgets/catalog/favorite_products_mixin.dart';

class _MockFetchFavorites extends Mock implements FetchFavorites {}

class _MockToggleFavorite extends Mock implements ToggleFavorite {}

Product _product(String id, {String materialCode = 'MAT-1'}) => Product(
      id: id,
      familyId: 'f1',
      familyName: 'Roofing',
      code: 'C-$id',
      sku: 'SKU-$id',
      materialCode: materialCode,
      barcode: '000',
      name: 'Coil $id',
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
      stockQuantity: 10,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 1000,
      stockKnown: true,
    );

const _sapPrice =
    MobilePrice(material: 'MAT-1', state: PricingState.loaded, price: 42);

QuotationBuilderReady _ready(QuotationTotals totals) => QuotationBuilderReady(
      quotation: QuotationDetail(
        id: 'qt-1',
        number: 'QT-1',
        depotId: 'dep-1',
        depotName: 'Depot',
        status: 'Draft',
        statusGroup: QuotationStatusGroup.drafts,
        shipmentType: 'Pickup',
        currency: totals.currency,
        revision: 1,
        requiredApprovalLevel: 0,
        lines: const [],
        totals: totals,
      ),
    );

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with FavoriteProductsMixin {
  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  group('ManualPriceBook', () {
    test('remembers a price under both row id and material number', () {
      final book = ManualPriceBook()..remember(_product('row-1'), 12.5);
      expect(book.of(_product('row-1')), 12.5);
      // Same material at another warehouse: a different row, same price.
      expect(book.of(_product('row-2')), 12.5);
    });

    test('a non-positive price forgets it', () {
      final book = ManualPriceBook()
        ..remember(_product('row-1'), 12.5)
        ..remember(_product('row-1'), 0);
      expect(book.of(_product('row-1')), isNull);
    });

    test('a SAP price always wins over the rep', () {
      final book = ManualPriceBook()..remember(_product('row-1'), 12.5);
      expect(book.priceFor(_product('row-1'), _sapPrice), 42);
      expect(book.isManual(_product('row-1'), _sapPrice), isFalse);
    });

    test('without a SAP price the rep price is used and flagged manual', () {
      final book = ManualPriceBook()..remember(_product('row-1'), 12.5);
      const pending = MobilePrice.loading('MAT-1');
      expect(book.priceFor(_product('row-1'), pending), 12.5);
      expect(book.isManual(_product('row-1'), pending), isTrue);
      expect(book.priceFor(_product('row-1'), null), 12.5);
    });

    test('neither price answers null and not manual', () {
      final book = ManualPriceBook();
      expect(book.priceFor(_product('row-1'), null), isNull);
      expect(book.isManual(_product('row-1'), null), isFalse);
    });
  });

  group('QuotationBuilderTotals', () {
    // 2 × 50 at 10% off: subtotal 100, discount 10.
    final cart = CartLoaded(items: [
      CartItem(
        id: 'l1',
        product: _product('row-1'),
        quantity: 2,
        unit: 'sheet',
        discountPercent: 10,
        unitPriceOverride: 50,
      ),
    ]);

    test('estimates from the cart with 10% tax before the server answers', () {
      final t = QuotationBuilderTotals.resolve(
          const QuotationBuilderInitial(), cart,
          isTaxApplicable: true);
      expect(t.subtotal, 100);
      expect(t.discount, 10);
      expect(t.tax, closeTo(9, 1e-9));
      expect(t.total, closeTo(99, 1e-9));
      expect(t.currency, 'USD');
      expect(t.isEstimate, isFalse);
    });

    test('a commercial invoice carries no tax', () {
      final t = QuotationBuilderTotals.resolve(
          const QuotationBuilderLoading(), cart,
          isTaxApplicable: false);
      expect(t.tax, 0);
      expect(t.total, closeTo(90, 1e-9));
    });

    test('a discount above the subtotal never goes negative', () {
      final t = QuotationBuilderTotals.resolve(
          _ready(const QuotationTotals(
              currency: 'USD',
              gross: 10,
              discountTotal: 30,
              net: 0,
              isEstimate: false)),
          cart,
          isTaxApplicable: true);
      // Server gave no tax: estimated on a taxable amount clamped to zero.
      expect(t.tax, 0);
      expect(t.total, 0);
    });

    test('the server totals win over the cart', () {
      final t = QuotationBuilderTotals.resolve(
          _ready(const QuotationTotals(
              currency: 'KHR',
              gross: 200,
              discountTotal: 20,
              tax: 18,
              net: 198,
              isEstimate: true)),
          cart,
          isTaxApplicable: false);
      expect(t.subtotal, 200);
      expect(t.discount, 20);
      expect(t.tax, 18);
      expect(t.total, 198);
      expect(t.currency, 'KHR');
      expect(t.isEstimate, isTrue);
    });

    test('no cart and no server is all zeros', () {
      final t = QuotationBuilderTotals.resolve(
          const QuotationBuilderInitial(), const CartLoading(),
          isTaxApplicable: true);
      expect(t.subtotal, 0);
      expect(t.total, 0);
    });
  });

  group('FavoriteProductsMixin', () {
    late _MockFetchFavorites fetch;
    late _MockToggleFavorite toggle;

    setUpAll(() {
      registerFallbackValue(const NoParams());
      registerFallbackValue(const ProductIdParams('p'));
    });

    setUp(() async {
      fetch = _MockFetchFavorites();
      toggle = _MockToggleFavorite();
      when(() => toggle(any())).thenAnswer((_) async => const Success(null));
      await GetIt.instance.reset();
      GetIt.instance
        ..registerFactory<FetchFavorites>(() => fetch)
        ..registerFactory<ToggleFavorite>(() => toggle);
    });
    tearDown(() async => GetIt.instance.reset());

    _HarnessState state(WidgetTester tester) =>
        tester.state<_HarnessState>(find.byType(_Harness));

    testWidgets('loads the favourite ids', (tester) async {
      when(() => fetch(any()))
          .thenAnswer((_) async => Success([_product('a'), _product('b')]));
      await tester.pumpWidget(const _Harness());
      await tester.pump();
      expect(state(tester).favoriteIds, {'a', 'b'});
    });

    testWidgets('a failed load leaves the set empty', (tester) async {
      when(() => fetch(any())).thenAnswer(
          (_) async => const Failed(ServerFailure(message: 'down')));
      await tester.pumpWidget(const _Harness());
      await tester.pump();
      expect(state(tester).favoriteIds, isEmpty);
    });

    testWidgets('toggling flips the heart and writes', (tester) async {
      when(() => fetch(any()))
          .thenAnswer((_) async => Success([_product('a')]));
      await tester.pumpWidget(const _Harness());
      await tester.pump();

      await state(tester).toggleFavorite(_product('a'));
      expect(state(tester).favoriteIds, isEmpty);
      await state(tester).toggleFavorite(_product('b'));
      expect(state(tester).favoriteIds, {'b'});
      verify(() => toggle(const ProductIdParams('a'))).called(1);
      verify(() => toggle(const ProductIdParams('b'))).called(1);
    });
  });
}
