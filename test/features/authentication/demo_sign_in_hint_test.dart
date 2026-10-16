import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/demo_sign_in_hint.dart';

void main() {
  Future<void> pump(WidgetTester tester, VoidCallback onFill,
      {String lang = 'en'}) async {
    await tester.runAsync(() => LocalizationService.instance.load(lang));
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(lang == 'km'
            ? AppTypography.khmerFontFamily
            : AppTypography.latinFontFamily),
        home: Scaffold(body: DemoSignInHint(onFill: onFill)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('names the demo account and fills it on request', (tester) async {
    var fills = 0;
    await pump(tester, () => fills++);

    expect(
      find.text('Demo mode — sign in with '
          '${DemoSeed.signInPhone} / ${DemoSeed.signInPassword}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Fill demo account'));
    expect(fills, 1);
  });

  testWidgets('renders in Khmer without overflow', (tester) async {
    await pump(tester, () {}, lang: 'km');
    expect(find.text('បំពេញគណនីសាកល្បង'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
