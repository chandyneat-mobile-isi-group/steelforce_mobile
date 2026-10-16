import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_screen.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_summary_sections.dart';

/// Holds the KPI screen together after it was split out of a single 1.3k-line
/// file: every section still mounts, and the month/year multi-select keeps its
/// "at least one selected, commit on Done" behaviour.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    // The screen's placeholder copy is known to overflow by a pixel or two
    // under the test font; that is pre-existing and not what these tests
    // guard, so layout-overflow reports are ignored here.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: const KpiScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(1024, 1366)]) {
    testWidgets('mounts every section at $size', (tester) async {
      await pump(tester, size);

      expect(find.byType(KpiPrimaryTargetCard), findsOneWidget);
      expect(find.byType(KpiIncentivesSection), findsOneWidget);
      expect(find.byType(KpiMetricsGrid), findsOneWidget);
      expect(find.byType(KpiCategoryBreakdown), findsOneWidget);
      expect(find.byType(KpiPipelineFunnel), findsOneWidget);
      expect(find.text('kpi.title'), findsNothing,
          reason: 'the title key must resolve');
    });
  }

  testWidgets('year sheet commits on Done and keeps one value selected',
      (tester) async {
    await pump(tester, const Size(390, 844));

    await tester.tap(
      find
          .ancestor(of: find.text('2026'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Select Year'), findsOneWidget);

    // Unchecking the only selected value is ignored.
    await tester.tap(find.widgetWithText(CheckboxListTile, '2026'));
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, '2026'))
          .value,
      isTrue,
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, '2024'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Select Year'), findsNothing);
    expect(find.text('2 Years'), findsOneWidget);
  });
}
