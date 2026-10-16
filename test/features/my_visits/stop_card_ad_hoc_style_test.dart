import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/presentation/models/today_stop.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/stop_card.dart';

/// An ad hoc stop must be told apart from a Call Plan stop at a glance: the
/// brand rail and the solid chip are what carry that, so both are pinned — and
/// pinned *absent* on a Call Plan card, which must look exactly as before.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  TodayStop stopFrom(VisitSource source) => TodayStop(
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
          sequence: source == VisitSource.adHoc ? 1001 : 1,
          plannedArrival: null,
          plannedDeparture: null,
          status: VisitStatus.pending,
          visitSource: source,
        ),
        routeId: 'r1',
        routeName: 'PP Central',
      );

  Future<void> pump(
    WidgetTester tester,
    VisitSource source, {
    bool dark = false,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final font = AppTypography.latinFontFamily;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: dark ? AppTheme.dark(font) : AppTheme.light(font),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: ListView(children: [
              StopCard(todayStop: stopFrom(source), onTap: () {}),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder rail() => find.descendant(
        of: find.byType(StopCard),
        matching: find.byWidgetPredicate((w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null),
      );

  testWidgets('an ad hoc stop carries the brand rail and the chip',
      (tester) async {
    await pump(tester, VisitSource.adHoc);

    expect(rail(), findsOneWidget);
    expect(find.text('Ad hoc'), findsOneWidget);
    expect(find.byIcon(Icons.add_location_alt_rounded), findsOneWidget);
    // 1001 is an ordering device, never a position the rep reads.
    expect(find.text('1001'), findsNothing);
  });

  testWidgets('a Call Plan stop looks exactly as it did', (tester) async {
    await pump(tester, VisitSource.callPlan);

    expect(rail(), findsNothing);
    expect(find.text('Ad hoc'), findsNothing);
    expect(find.byIcon(Icons.add_location_alt_rounded), findsNothing);
  });

  testWidgets('the ad hoc styling holds in dark mode and at 200% text',
      (tester) async {
    await pump(tester, VisitSource.adHoc, dark: true, textScale: 2.0);

    expect(tester.takeException(), isNull);
    expect(rail(), findsOneWidget);
  });
}
