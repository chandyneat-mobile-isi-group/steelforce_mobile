import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/shell/presentation/widgets/monthly_target_widget.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  Future<void> pumpCard(WidgetTester tester,
      {required double achieved, required double target}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: Scaffold(
          body: MonthlyTargetCard(
            targetAmount: target,
            achievedAmount: achieved,
            monthName: 'October',
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('amounts are grouped in thousands with the dollar sign after',
      (tester) async {
    await pumpCard(tester, achieved: 100000, target: 1250000);

    expect(find.text('100,000\$'), findsOneWidget);
    expect(find.text('/ 1,250,000\$'), findsOneWidget);
  });

  testWidgets('small and fractional amounts show whole dollars only',
      (tester) async {
    await pumpCard(tester, achieved: 999.99, target: 0);

    // Truncated, not rounded: 999.99 has not reached 1,000 yet.
    expect(find.text('999\$'), findsOneWidget);
    expect(find.text('/ 0\$'), findsOneWidget);
  });
}
