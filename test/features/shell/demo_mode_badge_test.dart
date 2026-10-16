import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/shell/presentation/widgets/demo_mode_badge.dart';

void main() {
  Future<void> pump(WidgetTester tester, DemoNetwork network,
      {String lang = 'en'}) async {
    await tester.runAsync(() => LocalizationService.instance.load(lang));
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(lang == 'km'
            ? AppTypography.khmerFontFamily
            : AppTypography.latinFontFamily),
        builder: (context, child) =>
            DemoModeOverlay(network: network, child: child!),
        home: const Scaffold(body: Text('app body')),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping toggles the demo network and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    final network = DemoNetwork();
    await pump(tester, network);

    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('online'), findsOneWidget);
    expect(find.bySemanticsLabel('Demo mode, network online'), findsOneWidget);

    await tester.tap(find.byType(DemoModeBadge));
    await tester.pump();
    expect(network.isOnline, isFalse);
    expect(find.text('Demo network: offline'), findsOneWidget);
    expect(find.bySemanticsLabel('Demo mode, network offline'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.byType(DemoModeBadge));
    await tester.pump();
    expect(network.isOnline, isTrue);
    expect(find.text('Demo network: online'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('follows a network change made elsewhere', (tester) async {
    final semantics = tester.ensureSemantics();
    final network = DemoNetwork();
    await pump(tester, network);

    network.setOnline(false);
    await tester.pump();
    expect(find.bySemanticsLabel('Demo mode, network offline'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the strip spans the width and sits above the app, not over it',
      (tester) async {
    await pump(tester, DemoNetwork());
    final strip = tester.getRect(find.byType(InkWell));
    final body = tester.getRect(find.text('app body'));
    expect(strip.width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio);
    expect(strip.height, greaterThanOrEqualTo(32));
    expect(body.top, greaterThanOrEqualTo(strip.bottom));
  });

  testWidgets('renders in Khmer', (tester) async {
    await pump(tester, DemoNetwork(), lang: 'km');
    expect(find.text('សាកល្បង'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the overlay is a pass-through outside a demo build',
      skip: DataSourceMode.useMocks, (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: DemoModeOverlay(child: Text('app')),
    ));
    expect(find.text('app'), findsOneWidget);
    expect(find.byType(DemoModeBadge), findsNothing);
  });
}
