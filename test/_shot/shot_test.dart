import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_sheet.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_coming_soon_screen.dart';

void main() {
  for (final lang in ['en', 'km']) {
    testWidgets('shot $lang', (tester) async {
      await tester.runAsync(() => LocalizationService.instance.load(lang));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: Builder(
              builder: (c) => Scaffold(
                  body: Center(
                      child: TextButton(
                          onPressed: () => showNotificationsSheet(context: c),
                          child: const Text('bell'))))),
        ),
      ));
      await tester.tap(find.text('bell'));
      await tester.pumpAndSettle();
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('sheet_$lang.png'));
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            home: const KpiComingSoonScreen()),
      ));
      await tester.pumpAndSettle();
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('kpi_$lang.png'));
    });
  }
}
