import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/stop_information_screen.dart';

/// The regression this file exists for: the start-visit bar used to be wrapped
/// in a bare `ResponsiveContentFrame`. Scaffold measures `bottomNavigationBar`
/// against loose *full-screen* constraints, so its `Align` (no `heightFactor`)
/// grew to the entire screen height on any non-compact window, leaving the body
/// zero-height and painting the bar over the AppBar.
void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  const phone = Size(390, 844);

  final stop = RouteStop(
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
    plannedArrival: DateTime(2026, 8, 17, 9),
    plannedDeparture: DateTime(2026, 8, 17, 10),
    status: VisitStatus.pending,
  );

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: Breakpoints.fromWidth(size.width).isCompact ? phone : size,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: StopInformationScreen(stop: stop, index: 0, totalStops: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(390, 844), // iPhone — compact
    Size(834, 1112), // iPad Air portrait — medium
    Size(1032, 1366), // iPad Pro 13" portrait — medium
    Size(1366, 1024), // iPad Pro landscape — expanded
  ]) {
    testWidgets('body keeps its height at ${size.width.toInt()}pt',
        (tester) async {
      await pumpScreen(tester, size);

      // The bar shrink-wraps and stays at the bottom. When it stretched to the
      // full screen height its `topCenter` child landed at y = 0 instead.
      final button = tester.getRect(find.byType(ElevatedButton));
      expect(button.top, greaterThan(size.height * 0.75));
      expect(button.bottom, lessThanOrEqualTo(size.height));

      // The body actually got laid out.
      final listHeight = tester.getSize(find.byType(ListView)).height;
      expect(listHeight, greaterThan(size.height / 2));

      // The AppBar is not covered — its title is on screen and above the list.
      expect(find.text('Outlet Information'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Outlet Information')).dy,
        lessThan(tester.getTopLeft(find.byType(ListView)).dy),
      );

      // Content renders.
      expect(find.text('Outlet ID (BP SAP)'), findsOneWidget);
      expect(find.text('Outlet Details & Location'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('two-column layout only above the 840pt threshold',
      (tester) async {
    await pumpScreen(tester, const Size(390, 844));
    expect(find.text('Promotions'), findsOneWidget);
    final narrowTop = tester.getTopLeft(find.text('Promotions')).dy;
    final narrowInfoTop =
        tester.getTopLeft(find.text('Outlet Details & Location')).dy;
    // Stacked: promotions sit below the outlet card.
    expect(narrowTop, greaterThan(narrowInfoTop));

    await pumpScreen(tester, const Size(1032, 1366));
    final wideTop = tester.getTopLeft(find.text('Promotions')).dy;
    final wideInfoTop =
        tester.getTopLeft(find.text('Outlet Details & Location')).dy;
    // Side by side: both section headers start on the same row.
    expect((wideTop - wideInfoTop).abs(), lessThan(4));
  });
}
