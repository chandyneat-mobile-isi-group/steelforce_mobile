import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/config/feature_flags.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_sheet.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_coming_soon_screen.dart';

/// KPI and notifications, switched off in the demo build: each says it
/// arrives in the next version and offers one way out.
void main() {
  test('KPI and notifications are off in the demo build only', () {
    expect(FeatureFlags.kpi, !DataSourceMode.useMocks);
    expect(FeatureFlags.notifications, !DataSourceMode.useMocks);
  });

  Future<void> pump(WidgetTester tester, Widget home,
      {String language = 'en', double width = 390}) async {
    await tester.runAsync(() => LocalizationService.instance.load(language));
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('KPI coming soon: Back to Home leaves the screen',
      (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KpiComingSoonScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('kpi.coming_soon.title'.tr), findsOneWidget);

    await tester.tap(find.text('kpi.coming_soon.back_home'.tr));
    await tester.pumpAndSettle();
    expect(find.byType(KpiComingSoonScreen), findsNothing);
  });

  testWidgets('the notifications sheet says coming soon and closes',
      (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showNotificationsSheet(context: context),
            child: const Text('bell'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('bell'));
    await tester.pumpAndSettle();
    expect(find.text('notifications.coming_soon.title'.tr), findsOneWidget);

    await tester.tap(find.text('common.close'.tr));
    await tester.pumpAndSettle();
    expect(find.text('notifications.coming_soon.title'.tr), findsNothing);
  }, skip: FeatureFlags.notifications);

  for (final language in ['en', 'km']) {
    testWidgets('KPI coming soon fits a 320pt phone ($language)',
        (tester) async {
      await pump(tester, const KpiComingSoonScreen(),
          language: language, width: 320);
      expect(tester.takeException(), isNull);
      expect(find.text('kpi.coming_soon.subtitle'.tr), findsOneWidget);
    });
  }
}
