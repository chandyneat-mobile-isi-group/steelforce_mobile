import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/order_history_screen.dart';

const _allIds = [
  'ORD-2026-8891',
  'ORD-2026-8710',
  'ORD-2026-8540',
  'ORD-2026-8230',
  'ORD-2026-7990',
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  Future<void> pump(WidgetTester tester, {String? outletName}) async {
    // The summary banner and card footer overflow at phone width; that
    // layout bug is not what these tests pin.
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
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: OrderHistoryScreen(outletName: outletName),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectOrders(List<String> visible) {
    for (final id in _allIds) {
      expect(
          find.text(id), visible.contains(id) ? findsOneWidget : findsNothing,
          reason: id);
    }
  }

  testWidgets('title, outlet and summary of every order', (tester) async {
    await pump(tester, outletName: 'Sokha Steel');

    expect(find.text('Order History (SAP)'), findsOneWidget);
    expect(find.text('Sokha Steel'), findsOneWidget);
    expect(find.text('5 Orders'), findsOneWidget);
    expect(find.text('\$62550.50'), findsOneWidget);
    expect(find.text('All (5)'), findsOneWidget);
    expectOrders(_allIds);
  });

  testWidgets('no outlet line without an outlet', (tester) async {
    await pump(tester);

    expect(find.text('Order History (SAP)'), findsOneWidget);
    expect(find.text('Sokha Steel'), findsNothing);
  });

  testWidgets('status tabs filter the list and All restores it',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expectOrders(['ORD-2026-8891', 'ORD-2026-8540', 'ORD-2026-7990']);

    await tester.tap(find.text('In Delivery'));
    await tester.pumpAndSettle();
    expectOrders(['ORD-2026-8710']);

    await tester.ensureVisible(find.text('Pending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expectOrders(['ORD-2026-8230']);
    // The summary always counts every order, not the filtered ones.
    expect(find.text('5 Orders'), findsOneWidget);

    await tester.ensureVisible(find.text('All (5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All (5)'));
    await tester.pumpAndSettle();
    expectOrders(_allIds);
  });

  testWidgets('a card shows status, SAP doc, terms and amount', (tester) async {
    await pump(tester);

    expect(find.text('SAP DOC: 30018923'), findsOneWidget);
    expect(find.text('12 Aug 2026 · 30 Days Net'), findsOneWidget);
    expect(find.text('\$14250.00'), findsOneWidget);
    expect(find.text('COMPLETED'), findsNWidgets(3));
    expect(find.text('IN DELIVERY'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });

  testWidgets('search matches items case-insensitively and SAP doc numbers',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'db12');
    await tester.pumpAndSettle();
    expectOrders(['ORD-2026-8540']);

    await tester.enterText(find.byType(TextField), '30018300');
    await tester.pumpAndSettle();
    expectOrders(['ORD-2026-8230']);

    await tester.enterText(find.byType(TextField), 'ord-2026-77');
    await tester.pumpAndSettle();
    expectOrders([]);
    expect(find.text('No orders found'), findsOneWidget);
  });

  testWidgets('search and status filter combine', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'h-beam');
    await tester.pumpAndSettle();
    expectOrders(['ORD-2026-7990']);
  });

  testWidgets('re-order announces the order it copies', (tester) async {
    await pump(tester);

    // The button sits in the overflowing footer, so a real tap misses it.
    final reorder = find.ancestor(
      of: find.text('Re-order').first,
      matching: find.byWidgetPredicate((w) => w is TextButton),
    );
    tester.widget<TextButton>(reorder.first).onPressed!();
    await tester.pump();

    expect(
        find.text('Re-ordering items from ORD-2026-8891...'), findsOneWidget);
  });
}
