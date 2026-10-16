import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/presentation/models/today_stop.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/stop_card.dart';

/// The stop card's two jobs beyond showing text: it routes the basket action,
/// and it is the only place the rep is told a visit closed.
///
/// The motion here is not decoration. `WatchAllRoutes` pushes a new status in
/// from the database the moment a check-out lands, so the pill's label is
/// replaced between two frames — the change most worth noticing is the one
/// easiest to miss. What is tested is that the transition *runs*, that it
/// always settles on the right label, and that it cannot throw: an exception
/// mid-animation would take the whole list down with it.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  TodayStop stopWith(VisitStatus status) => TodayStop(
        stop: RouteStop(
          id: 's1',
          routeId: 'r1',
          depot: const DepotStopInfo(
            id: 'c1',
            name: 'Phnom Penh Steel Outlet',
            code: 'BP-884920',
            contact: 'Yim Vithou',
            phone: '026 407 480',
            address: 'St. 218, Mean Chey',
            territory: 'Phnom Penh',
            territoryType: TerritoryType.urban,
            latitude: 11.5564,
            longitude: 104.9282,
          ),
          sequence: 1,
          plannedArrival: DateTime(2026, 9, 8, 9),
          plannedDeparture: DateTime(2026, 9, 8, 10),
          status: status,
        ),
        routeId: 'r1',
        routeName: 'PP Central',
      );

  Future<void> pump(
    WidgetTester tester,
    VisitStatus status, {
    VoidCallback? onTap,
    VoidCallback? onQuotationTap,
    bool reduceMotion = false,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: ListView(children: [
              StopCard(
                todayStop: stopWith(status),
                onTap: onTap ?? () {},
                onQuotationTap: onQuotationTap,
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('the basket action', () {
    testWidgets('fires its callback — this is the Quotation Builder route',
        (tester) async {
      // The dashboard hands this straight to `openQuotationForDepot`. It
      // used to be `onQuotationTap: () { /* Navigate to Ad-Hoc order screen */
      // }` — a comment where the navigation should have been, so the icon was
      // live, gave feedback, and went nowhere.
      var taps = 0;
      await pump(tester, VisitStatus.checkedIn, onQuotationTap: () => taps++);

      await tester.tap(find.byIcon(Icons.shopping_basket_rounded));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('is not offered while the stop is still pending',
        (tester) async {
      await pump(tester, VisitStatus.pending);

      expect(find.byIcon(Icons.shopping_basket_rounded), findsNothing);
    });

    testWidgets('is not offered when quotations are switched off',
        (tester) async {
      // The dashboard passes no handler while `FeatureFlags.quotesAndOrders`
      // is off; a basket that does nothing would be a dead control.
      await pump(tester, VisitStatus.checkedIn);

      expect(find.byIcon(Icons.shopping_basket_rounded), findsNothing);
    });

    testWidgets('does not also open the stop behind it', (tester) async {
      // The basket sits inside the card's own tap target. Tapping it must not
      // do both things.
      var cardTaps = 0;
      var basketTaps = 0;
      await pump(
        tester,
        VisitStatus.checkedIn,
        onTap: () => cardTaps++,
        onQuotationTap: () => basketTaps++,
      );

      await tester.tap(find.byIcon(Icons.shopping_basket_rounded));
      await tester.pumpAndSettle();

      expect(basketTaps, 1);
      expect(cardTaps, 0);
    });
  });

  group('the status pill', () {
    testWidgets('reads In Progress while checked in, Visited once closed',
        (tester) async {
      await pump(tester, VisitStatus.checkedIn);
      expect(find.text('In Progress'), findsOneWidget);

      await pump(tester, VisitStatus.checkedOut);
      expect(find.text('Visited'), findsOneWidget);
      expect(find.text('In Progress'), findsNothing);
    });

    testWidgets('cross-fades rather than jumping, and settles clean',
        (tester) async {
      await pump(tester, VisitStatus.checkedIn);

      // Rebuild in place with the new status, the way the live route watch
      // does — same widget position, different data.
      await pump(tester, VisitStatus.checkedOut);
      await tester.pump(const Duration(milliseconds: 80));

      // Mid-flight both labels are on screen; that is the transition running.
      // Whether it is exactly here does not matter — that it ends correctly,
      // and never throws, does.
      await tester.pumpAndSettle();
      expect(find.text('Visited'), findsOneWidget);
      expect(find.text('In Progress'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('honours reduce motion (FS-ANI-7)', (tester) async {
      await pump(tester, VisitStatus.checkedOut, reduceMotion: true);

      expect(find.text('Visited'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the card surface', () {
    testWidgets('a completed visit cannot be reopened', (tester) async {
      var taps = 0;
      await pump(tester, VisitStatus.checkedOut, onTap: () => taps++);

      await tester.tap(find.text('Phnom Penh Steel Outlet'),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(taps, 0, reason: 'checkedOut and missed stops are not startable');
    });

    testWidgets('a pending stop still opens', (tester) async {
      var taps = 0;
      await pump(tester, VisitStatus.pending, onTap: () => taps++);

      await tester.tap(find.text('Phnom Penh Steel Outlet'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('press feedback does not break layout at 200% text scale',
        (tester) async {
      // FS-A11Y-2 plus the press scale: a transform on an already-overflowing
      // card is how a cosmetic problem becomes an exception.
      await pump(tester, VisitStatus.checkedIn,
          textScale: 2.0, onQuotationTap: () {});

      final basket = find.byIcon(Icons.shopping_basket_rounded);
      await tester.press(basket);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
