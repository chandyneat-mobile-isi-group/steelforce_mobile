import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/visit_step_bar.dart';

/// The visit step bar: which step a stop is on, what screen readers hear,
/// and that five labels fit a small phone in both languages.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBar(WidgetTester tester, VisitStep? current,
      {double width = 320}) async {
    tester.view.physicalSize = Size(width, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('t'),
            bottom: VisitStepBar(current: current),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  test('maps stop status to the step it waits on', () {
    expect(VisitStepBar.forStatus(VisitStatus.pending), VisitStep.details);
    expect(VisitStepBar.forStatus(VisitStatus.arrived), VisitStep.details);
    expect(VisitStepBar.forStatus(VisitStatus.checkedIn), VisitStep.inventory);
    expect(VisitStepBar.forStatus(VisitStatus.checkedOut), isNull);
  });

  for (final language in ['en', 'km']) {
    testWidgets('five labels fit 320pt ($language)', (tester) async {
      await tester.runAsync(() => LocalizationService.instance.load(language));
      await pumpBar(tester, VisitStep.checkIn);
      expect(tester.takeException(), isNull);
      for (final key in [
        'stop',
        'details',
        'check_in',
        'inventory',
        'check_out'
      ]) {
        expect(find.text('my_visits.steps.$key'.tr), findsOneWidget);
      }
    });
  }

  testWidgets('announces the current step', (tester) async {
    await tester.runAsync(() => LocalizationService.instance.load('en'));
    final handle = tester.ensureSemantics();
    await pumpBar(tester, VisitStep.inventory);
    expect(
        find.bySemanticsLabel('Visit step 4 of 5: Inventory'), findsOneWidget);
    // Earlier steps show a tick, later ones their number.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(find.text('5'), findsOneWidget);
    handle.dispose();
  });
}
