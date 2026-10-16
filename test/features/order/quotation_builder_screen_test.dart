import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/fetch_favorites.dart';
import 'package:steelforce/features/order/domain/usecases/toggle_favorite.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/stock_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_state.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/bloc/promotion/promotion_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_state.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_state.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_builder_screen.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_detail_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_preview_section.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/shipment_widget_section.dart';

class _MockFlowBloc
    extends MockBloc<ProductFilterFlowEvent, ProductFilterFlowState>
    implements ProductFilterFlowBloc {}

class _MockCartCubit extends MockCubit<CartState> implements CartCubit {}

class _MockSyncCubit extends MockCubit<SyncState> implements SyncCubit {}

class _MockStockCubit extends MockCubit<Map<String, MaterialAvailability>>
    implements StockCubit {}

class _MockPricingCubit extends MockCubit<Map<String, MobilePrice>>
    implements PricingCubit {}

class _MockPromotionCubit extends MockCubit<Map<String, PromotionEvaluation>>
    implements PromotionCubit {}

class _MockBuilderCubit extends MockCubit<QuotationBuilderState>
    implements QuotationBuilderCubit {}

class _MockDetailCubit extends MockCubit<QuotationDetailState>
    implements QuotationDetailCubit {}

class _MockFetchFavorites extends Mock implements FetchFavorites {}

class _MockToggleFavorite extends Mock implements ToggleFavorite {}

Product _product() => Product(
      id: 'p1',
      familyId: 'f1',
      familyName: 'Roofing',
      code: 'C-1',
      sku: 'SKU-1',
      materialCode: 'MAT-1',
      barcode: '000',
      name: 'Coil 1',
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

/// 2 × 50 at 10% off: subtotal 100, discount 10, taxable 90.
CartLoaded _cart() => CartLoaded(items: [
      CartItem(
        id: 'line-1',
        product: _product(),
        quantity: 2,
        unit: 'sheet',
        discountPercent: 10,
        unitPriceOverride: 50,
      ),
    ]);

QuotationBuilderReady _serverReady() => QuotationBuilderReady(
      quotation: QuotationDetail(
        id: 'qt-1',
        number: 'QT-0001',
        depotId: 'dep-1',
        depotName: 'Depot One',
        status: 'Draft',
        statusGroup: QuotationStatusGroup.drafts,
        shipmentType: 'Pickup',
        currency: 'KHR',
        revision: 1,
        requiredApprovalLevel: 2,
        lines: const [],
        totals: const QuotationTotals(
          currency: 'KHR',
          gross: 200,
          discountTotal: 20,
          tax: 18,
          net: 198,
          isEstimate: true,
        ),
      ),
    );

/// Pins the totals the builder shows and saves, before the screen is split.
void main() {
  late _MockCartCubit cart;
  late _MockSyncCubit sync;
  late _MockBuilderCubit builder;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
    registerFallbackValue(const NoParams());
    registerFallbackValue(const ProductIdParams('p'));
  });

  setUp(() async {
    cart = _MockCartCubit();
    sync = _MockSyncCubit();
    builder = _MockBuilderCubit();
    final flow = _MockFlowBloc();
    final stock = _MockStockCubit();
    final pricing = _MockPricingCubit();
    final promotions = _MockPromotionCubit();
    final favorites = _MockFetchFavorites();

    when(() => cart.state).thenReturn(_cart());
    when(() => sync.state).thenReturn(const SyncIdle());
    when(() => sync.syncIfNeeded()).thenAnswer((_) async {});
    when(() => flow.state).thenReturn(const ProductFilterFlowState());
    when(() => stock.state).thenReturn(const {});
    when(() => stock.ensure(any())).thenAnswer((_) async {});
    when(() => pricing.state).thenReturn(const {});
    when(() => pricing.setDepot(any())).thenAnswer((_) async {});
    when(() => pricing.track(any())).thenAnswer((_) async {});
    when(() => promotions.state).thenReturn(const {});
    when(() => builder.state).thenReturn(const QuotationBuilderInitial());
    when(() => builder.initialize(
          depotId: any(named: 'depotId'),
          existingQuotationId: any(named: 'existingQuotationId'),
          shipmentType: any(named: 'shipmentType'),
          shipTo: any(named: 'shipTo'),
        )).thenAnswer((_) async {});
    when(() => favorites(any())).thenAnswer((_) async => const Success([]));

    final sl = GetIt.instance;
    await sl.reset();
    sl
      ..registerFactory<ProductFilterFlowBloc>(() => flow)
      ..registerFactory<StockCubit>(() => stock)
      ..registerFactory<PricingCubit>(() => pricing)
      ..registerFactory<PromotionCubit>(() => promotions)
      ..registerFactory<QuotationBuilderCubit>(() => builder)
      ..registerFactory<FetchFavorites>(() => favorites)
      ..registerFactory<ToggleFavorite>(_MockToggleFavorite.new);
  });
  tearDown(() async => GetIt.instance.reset());

  Future<void> pump(WidgetTester tester) async {
    // These tests pin values handed to child widgets, not pixels; the test
    // font is wider than the shipped one, so leaf rows report overflow here.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    tester.view.physicalSize = const Size(390, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<CartCubit>.value(value: cart),
            BlocProvider<SyncCubit>.value(value: sync),
          ],
          child: const QuotationBuilderScreen(
            depotId: 'dep-1',
            leadDisplayName: 'Lead Shop',
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  QuotationPreviewSection preview(WidgetTester tester) => tester
      .widget<QuotationPreviewSection>(find.byType(QuotationPreviewSection));

  testWidgets('opens a server draft for the depot id', (tester) async {
    await pump(tester);
    verify(() => builder.initialize(
          depotId: 'dep-1',
          existingQuotationId: null,
          shipmentType: 'Pickup',
          shipTo: null,
        )).called(1);
    verify(() => sync.syncIfNeeded()).called(1);
  });

  testWidgets(
      'without a server preview the cart estimate is shown with 10% tax',
      (tester) async {
    await pump(tester);
    final p = preview(tester);
    expect(p.shopName, 'Lead Shop');
    expect(p.subtotal, 100);
    expect(p.discount, 10);
    expect(p.tax, closeTo(9, 1e-9));
    expect(p.total, closeTo(99, 1e-9));
    expect(p.currency, 'USD');
    expect(p.isEstimate, isFalse);
    expect(p.requiredApprovalLevel, 0);
    expect(p.isTaxApplicable, isTrue);
  });

  testWidgets('a commercial invoice drops the tax from the estimate',
      (tester) async {
    await pump(tester);
    tester
        .widget<ShipmentSelectionWidget>(find.byType(ShipmentSelectionWidget))
        .onTaxApplicableChanged!(false);
    await tester.pump();
    final p = preview(tester);
    expect(p.tax, 0);
    expect(p.total, closeTo(90, 1e-9));
    expect(p.isTaxApplicable, isFalse);
  });

  testWidgets('a server preview wins over the cart estimate', (tester) async {
    when(() => builder.state).thenReturn(_serverReady());
    await pump(tester);
    final p = preview(tester);
    expect(p.subtotal, 200);
    expect(p.discount, 20);
    expect(p.tax, 18);
    expect(p.total, 198);
    expect(p.currency, 'KHR');
    expect(p.isEstimate, isTrue);
    expect(p.requiredApprovalLevel, 2);
  });

  testWidgets('save failure with nothing to open says so', (tester) async {
    when(() => cart.saveQuotation(
          depotId: any(named: 'depotId'),
          shopName: any(named: 'shopName'),
          leadId: any(named: 'leadId'),
          leadDisplayName: any(named: 'leadDisplayName'),
          offVisitReason: any(named: 'offVisitReason'),
          gpsLat: any(named: 'gpsLat'),
          gpsLng: any(named: 'gpsLng'),
          editing: any(named: 'editing'),
          subtotal: any(named: 'subtotal'),
          discount: any(named: 'discount'),
          tax: any(named: 'tax'),
          total: any(named: 'total'),
          remoteId: any(named: 'remoteId'),
        )).thenAnswer((_) async => null);
    await pump(tester);

    await tester.tap(find.text('orders.quotation.save_to_sap'.tr).last);
    await tester.pump();

    final captured = verify(() => cart.saveQuotation(
          depotId: null,
          shopName: null,
          leadId: null,
          leadDisplayName: 'Lead Shop',
          offVisitReason: null,
          gpsLat: null,
          gpsLng: null,
          editing: null,
          subtotal: captureAny(named: 'subtotal'),
          discount: captureAny(named: 'discount'),
          tax: captureAny(named: 'tax'),
          total: captureAny(named: 'total'),
          remoteId: null,
        )).captured;
    expect(captured[0], 100);
    expect(captured[1], 10);
    expect(captured[2] as double, closeTo(9, 1e-9));
    expect(captured[3] as double, closeTo(99, 1e-9));
    expect(find.text('orders.quotation_extra.save_failed'.tr), findsOneWidget);
  });

  testWidgets('save with a server draft sends its totals and opens it',
      (tester) async {
    final detail = _MockDetailCubit();
    when(() => detail.state).thenReturn(const QuotationDetailLoading());
    when(() => detail.load(any())).thenAnswer((_) async {});
    GetIt.instance.registerFactory<QuotationDetailCubit>(() => detail);
    when(() => builder.state).thenReturn(_serverReady());
    when(() => cart.saveQuotation(
          depotId: any(named: 'depotId'),
          shopName: any(named: 'shopName'),
          leadId: any(named: 'leadId'),
          leadDisplayName: any(named: 'leadDisplayName'),
          offVisitReason: any(named: 'offVisitReason'),
          gpsLat: any(named: 'gpsLat'),
          gpsLng: any(named: 'gpsLng'),
          editing: any(named: 'editing'),
          subtotal: any(named: 'subtotal'),
          discount: any(named: 'discount'),
          tax: any(named: 'tax'),
          total: any(named: 'total'),
          remoteId: any(named: 'remoteId'),
        )).thenAnswer((_) async => null);
    await pump(tester);

    await tester.tap(find.text('orders.quotation.save_to_sap'.tr).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(() => cart.saveQuotation(
          depotId: null,
          shopName: null,
          leadId: null,
          leadDisplayName: 'Lead Shop',
          offVisitReason: null,
          gpsLat: null,
          gpsLng: null,
          editing: null,
          subtotal: 200,
          discount: 20,
          tax: 18,
          total: 198,
          remoteId: 'qt-1',
        )).called(1);
    expect(find.byType(QuotationDetailScreen), findsOneWidget);
    verify(() => detail.load('qt-1')).called(1);
  });
}
