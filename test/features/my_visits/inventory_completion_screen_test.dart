import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_completion_screen.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  Future<void> pumpScreen(WidgetTester tester,
      {bool reduceMotion = false, bool showCreateQuotation = true}) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: reduceMotion,
            ),
            child: InventoryCompletionScreen(
              outletName: 'ISI Depot Kampot',
              onCreateQuotation: () {},
              onEndVisit: () {},
              showCreateQuotation: showCreateQuotation,
            ),
          ),
        ),
      ),
    );
  }

  /// Lottie decodes its file off the fake clock.
  Future<void> letLottieLoad(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
      'shows the photo-submitted mascot, the result and both next actions',
      (tester) async {
    await pumpScreen(tester);
    await letLottieLoad(tester);

    final mascot = tester.widget<CoachMascot>(find.byType(CoachMascot));
    expect(mascot.animationAsset, CoachMascot.inventorySuccessAsset);
    expect(mascot.loop, isFalse);
    // Once for the hero image, once for the heading under it.
    expect(
        find.bySemanticsLabel('Inventory photo submitted'), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('Create Quotation can be hidden, leaving Complete Visit',
      (tester) async {
    await pumpScreen(tester, showCreateQuotation: false);
    await letLottieLoad(tester);

    expect(find.text('my_visits.route_info.create_quotation'.tr), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('my_visits.inventory.completion.complete_visit'.tr),
        findsOneWidget);
  });

  testWidgets('the celebration plays once and settles instead of looping',
      (tester) async {
    await pumpScreen(tester);
    await letLottieLoad(tester);

    // A looping mascot would never settle and this would time out.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion shows the settled picture with no animation',
      (tester) async {
    await pumpScreen(tester, reduceMotion: true);
    await letLottieLoad(tester);

    expect(
        tester.widget<CoachMascot>(find.byType(CoachMascot)).animate, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
