import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/config/feature_flags.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/order/presentation/screens/quotes_coming_soon_screen.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';

/// Quotations & Orders, switched off: a calm "coming soon" with a way home.
void main() {
  tearDown(() => GetIt.instance.reset());

  test('quotations and orders are off in the demo build only', () {
    expect(FeatureFlags.quotesAndOrders, !DataSourceMode.useMocks);
  });

  Future<void> pump(WidgetTester tester, String language,
      {double width = 390}) async {
    await tester.runAsync(() => LocalizationService.instance.load(language));
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) =>
          const MaterialApp(home: QuotesComingSoonScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('as the Orders tab, Back to Home switches the shell to Home',
      (tester) async {
    final tabs = ShellTabController()..goTo(ShellTab.orders);
    GetIt.instance.registerSingleton<ShellTabController>(tabs);
    await pump(tester, 'en');

    expect(find.text('orders.coming_soon.title'.tr), findsOneWidget);
    await tester.tap(find.text('orders.coming_soon.back_home'.tr));
    expect(tabs.value, ShellTab.home);
  });

  for (final language in ['en', 'km']) {
    testWidgets('fits a 320pt phone ($language)', (tester) async {
      await pump(tester, language, width: 320);
      expect(tester.takeException(), isNull);
      expect(find.text('orders.coming_soon.subtitle'.tr), findsOneWidget);
    });
  }
}
