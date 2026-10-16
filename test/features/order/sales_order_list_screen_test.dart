import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/entities/sales_order_status.dart';
import 'package:steelforce/features/order/domain/usecases/watch_sales_orders.dart';
import 'package:steelforce/features/order/presentation/bloc/sales_order/sales_order_list_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sales_order/sales_order_list_state.dart';
import 'package:steelforce/features/order/presentation/screens/sales_order/sales_order_detail_screen.dart';
import 'package:steelforce/features/order/presentation/screens/sales_order/sales_order_list_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/sales_order/sales_order_card.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSalesOrders extends Mock implements WatchSalesOrders {}

SalesOrder _order(
  String id, {
  required SalesOrderStatus status,
  required DateTime createdAt,
  double total = 100,
}) =>
    SalesOrder(
      id: id,
      quotationId: 'q-$id',
      lines: const [],
      subtotal: total,
      discount: 0,
      tax: 0,
      total: total,
      status: status,
      sapStatus: 'CREATED',
      createdAt: createdAt,
      shopName: 'Shop $id',
    );

void main() {
  late _MockWatchSalesOrders watchSalesOrders;

  final pending = _order('SO-1',
      status: SalesOrderStatus.pending,
      createdAt: DateTime(2026, 8, 1),
      total: 50);
  final confirmed = _order('SO-2',
      status: SalesOrderStatus.confirmed,
      createdAt: DateTime(2026, 8, 20),
      total: 150);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    await LocalizationService.instance.load('en');
    registerFallbackValue(const NoParams());
  });

  setUp(() async {
    watchSalesOrders = _MockWatchSalesOrders();
    // The screen resolves its cubit from DI, so the test container has to hold
    // one. Reset per test so a stale stream cannot leak between cases.
    //
    // `reset` is async — awaiting it matters: firing it without awaiting let
    // the registration below land first and then be wiped by the pending
    // reset, so the screen resolved nothing.
    await GetIt.instance.reset();
    GetIt.instance.registerFactory(
        () => SalesOrderListCubit(watchSalesOrders: watchSalesOrders));
  });
  tearDown(() async => GetIt.instance.reset());

  void streams(List<SalesOrder> orders) => when(() => watchSalesOrders(any()))
      .thenAnswer((_) => Stream.value(orders));

  Future<void> pump(WidgetTester tester,
      {SalesOrderFilter? initialFilter}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: SalesOrderListScreen(initialFilter: initialFilter),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every order, newest first', (tester) async {
    streams([pending, confirmed]);
    await pump(tester);

    expect(find.byType(SalesOrderCard), findsNWidgets(2));
    final cards = tester
        .widgetList<SalesOrderCard>(find.byType(SalesOrderCard))
        .map((c) => c.order.id)
        .toList();
    expect(cards, ['SO-2', 'SO-1']);
  });

  testWidgets('tapping an order opens its detail', (tester) async {
    streams([confirmed]);
    await pump(tester);

    await tester.tap(find.byType(SalesOrderCard));
    await tester.pumpAndSettle();

    // The whole point of the screen: a row is a way through to the order, not
    // a dead card. This is the same navigation the Orders list uses.
    expect(find.byType(SalesOrderDetailScreen), findsOneWidget);
    expect(find.text('QT-5512'), findsNothing); // detail shows *this* order
    expect(find.text('SO-2'), findsWidgets);
  });

  testWidgets('opens straight into the requested filter', (tester) async {
    streams([pending, confirmed]);
    await pump(tester, initialFilter: SalesOrderFilter.pending);

    // The home card's pending badge is the reason the rep tapped; landing on
    // the full list would make them filter again.
    expect(find.byType(SalesOrderCard), findsOneWidget);
    expect(tester.widget<SalesOrderCard>(find.byType(SalesOrderCard)).order.id,
        'SO-1');
  });

  testWidgets('a filter chip narrows the list', (tester) async {
    streams([pending, confirmed]);
    await pump(tester);

    expect(find.byType(SalesOrderCard), findsNWidgets(2));

    // Keyed, not text-matched: "Confirmed" is also the status badge on every
    // confirmed card, so a text finder is ambiguous.
    final chip = find.byKey(const ValueKey('sales-order-filter-confirmed'));
    // The filter bar scrolls horizontally; on a 390pt screen the last chip can
    // sit past the edge, where a tap silently lands on nothing.
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.byType(SalesOrderCard), findsOneWidget);
  });

  testWidgets('an empty database says so instead of showing a blank screen',
      (tester) async {
    streams(const []);
    await pump(tester);

    expect(find.byType(SalesOrderCard), findsNothing);
    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('a filtered-empty list explains itself differently',
      (tester) async {
    // Saying "no orders yet" to someone holding a confirmed order reads as a
    // bug, so the two empty states are worded apart.
    streams([confirmed]);
    await pump(tester, initialFilter: SalesOrderFilter.pending);

    expect(find.text('No orders yet'), findsNothing);
    expect(
        find.text(
            'No pending orders. Everything you have raised is confirmed.'),
        findsOneWidget);
  });

  testWidgets('a stream failure shows translated copy and a retry',
      (tester) async {
    when(() => watchSalesOrders(any()))
        .thenAnswer((_) => Stream.error(StateError('db gone')));
    await pump(tester);

    // Never the raw exception (FS-NN-4).
    expect(find.textContaining('db gone'), findsNothing);
    expect(find.text('Could not load your orders. Pull down or retry.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('does not overflow at 200% text scale', (tester) async {
    streams([pending, confirmed]);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: SalesOrderListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
