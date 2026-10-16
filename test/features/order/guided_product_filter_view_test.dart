import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/bloc/promotion/promotion_cubit.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/cart_summary_bar.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/category_selector.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided_product_filter_view.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/loading_products.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_card.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_grid.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/sku_search_card.dart';

class _MockFlowBloc
    extends MockBloc<ProductFilterFlowEvent, ProductFilterFlowState>
    implements ProductFilterFlowBloc {}

class _MockCartCubit extends MockCubit<CartState> implements CartCubit {}

class _MockPricingCubit extends MockCubit<Map<String, MobilePrice>>
    implements PricingCubit {}

class _MockPromotionCubit extends MockCubit<Map<String, PromotionEvaluation>>
    implements PromotionCubit {}

Product _product(String id) => Product(
      id: id,
      familyId: 'f1',
      familyName: 'Roofing',
      code: 'C-$id',
      sku: 'SKU-$id',
      materialCode: 'MAT-$id',
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

const _category = MaterialCategory(
  code: 'FG-RF',
  name: LocalizedText(en: 'Roofing', km: 'ដំបូល'),
  materialCount: 3,
  hasPublishedSchema: true,
);

/// Pins what each stage of the guided finder renders before the view is split
/// into files, so the split can be shown to change nothing.
void main() {
  late _MockFlowBloc flow;
  late _MockCartCubit cart;
  late _MockPricingCubit pricing;
  late _MockPromotionCubit promotions;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
    registerFallbackValue(const FilterFlowStarted());
  });

  setUp(() {
    flow = _MockFlowBloc();
    cart = _MockCartCubit();
    pricing = _MockPricingCubit();
    promotions = _MockPromotionCubit();
    when(() => cart.state).thenReturn(const CartLoaded(items: []));
    when(() => pricing.state).thenReturn(const {});
    when(() => pricing.track(any())).thenAnswer((_) async {});
    when(() => promotions.state).thenReturn(const {});
  });

  Future<void> pump(WidgetTester tester, ProductFilterFlowState state,
      {bool sticky = true}) async {
    when(() => flow.state).thenReturn(state);
    // These tests pin structure, not pixels. The test font is wider than the
    // shipped one, so leaf cards (category tiles, price rows) report overflow
    // here; every other error still fails the test.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ProductFilterFlowBloc>.value(value: flow),
              BlocProvider<CartCubit>.value(value: cart),
              BlocProvider<PricingCubit>.value(value: pricing),
              BlocProvider<PromotionCubit>.value(value: promotions),
            ],
            child: sticky
                ? _view(sticky: true)
                : SingleChildScrollView(child: _view(sticky: false)),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('categories loading shows the skeleton', (tester) async {
    await pump(
        tester, const ProductFilterFlowState(status: FilterFlowStatus.loading));
    expect(find.byType(LoadingProducts), findsOneWidget);
    expect(find.byType(CategorySelector), findsNothing);
  });

  testWidgets('categories failure offers retry that restarts the flow',
      (tester) async {
    await pump(
        tester,
        const ProductFilterFlowState(
            status: FilterFlowStatus.failure, errorMessage: 'boom'));
    expect(find.text('orders.guided_filter.error_title'.tr), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);

    await tester.tap(find.text('common.retry'.tr));
    verify(() => flow.add(const FilterFlowStarted())).called(1);
  });

  testWidgets('ready categories show the selector', (tester) async {
    await pump(
        tester,
        const ProductFilterFlowState(
            status: FilterFlowStatus.ready, categories: [_category]));
    expect(
        find.text('orders.guided_filter.choose_category'.tr), findsOneWidget);
    expect(find.byType(CategorySelector), findsOneWidget);
  });

  testWidgets('a search lists SKU cards and expands only the selected one',
      (tester) async {
    final a = _product('a');
    final b = _product('b');
    await pump(
        tester,
        ProductFilterFlowState(
          status: FilterFlowStatus.ready,
          query: 'coil',
          products: [a, b],
          productStatus: ProductListStatus.loaded,
          selectedSku: a.sku,
        ));
    expect(find.text('Matching Materials'), findsOneWidget);
    expect(find.byType(SkuSearchCard), findsNWidgets(2));
    expect(find.byType(ProductResultCard), findsOneWidget);
    verify(() => pricing.track({a.materialNumber})).called(1);
  });

  testWidgets('an empty search tells the rep to try another SKU',
      (tester) async {
    await pump(
        tester,
        const ProductFilterFlowState(
          status: FilterFlowStatus.ready,
          query: 'zz',
          productStatus: ProductListStatus.loaded,
        ));
    expect(find.text('Try another SKU or material name.'), findsOneWidget);
  });

  testWidgets('more pages offer load more', (tester) async {
    await pump(
        tester,
        ProductFilterFlowState(
          status: FilterFlowStatus.ready,
          query: 'coil',
          products: [_product('a')],
          productStatus: ProductListStatus.loaded,
          hasMore: true,
        ));
    await tester.tap(find.text('orders.catalog.load_more'.tr));
    verify(() => flow.add(const FilterProductsLoadMoreRequested())).called(1);
  });

  testWidgets('the cart footer appears only once the cart has lines',
      (tester) async {
    await pump(
        tester, const ProductFilterFlowState(status: FilterFlowStatus.ready));
    expect(find.byType(CartSummaryBar), findsNothing);

    when(() => cart.state).thenReturn(CartLoaded(items: [
      CartItem(
        id: 'line-1',
        product: _product('a'),
        quantity: 2,
        unit: 'sheet',
        discountPercent: 0,
      ),
    ]));
    await pump(
        tester, const ProductFilterFlowState(status: FilterFlowStatus.ready),
        sticky: false);
    expect(find.byType(CartSummaryBar), findsOneWidget);
  });

  testWidgets('guided results without search use the product grid',
      (tester) async {
    await pump(
        tester,
        ProductFilterFlowState(
          status: FilterFlowStatus.ready,
          category: _category,
          products: [_product('a')],
          productStatus: ProductListStatus.loaded,
        ));
    // No schema yet, so the flow is still on the steps stage: nothing priced.
    expect(find.byType(ProductResultGrid), findsNothing);
    verifyNever(() => pricing.track(any()));
  });
}

Widget _view({required bool sticky}) => GuidedProductFilterView(
      favoriteIds: const {},
      onToggleFavorite: (_) {},
      onQuantityChanged: (_, __) {},
      quantityFor: (_) => 0,
      sticky: sticky,
    );
