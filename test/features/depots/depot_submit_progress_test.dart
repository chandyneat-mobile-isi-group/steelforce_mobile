import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/depots/domain/entities/depot_submit_progress.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_submit_progress_dialog.dart';

/// The submit progress dialog.
///
/// The property worth defending is what it does **not** say. Submit never
/// calls SAP — the record is written to the platform and an operator or
/// scheduled job delivers it later — so a dialog animating "sending to SAP"
/// would tell a representative their shop is in the ERP when it is queued.
/// That is a difference they would act on, so it is asserted, not assumed.
void main() {
  setUpAll(() async {
    // `.tr` reads the loaded bundle; without this every label renders as its
    // raw key and the assertions below would pass on nonsense.
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  group('progress fraction', () {
    test('advances stage by stage', () {
      const validating = DepotSubmitProgress();
      const registering = DepotSubmitProgress(stage: SubmitStage.registering);
      const finishing = DepotSubmitProgress(stage: SubmitStage.finishing);

      expect(validating.fraction, 0);
      expect(registering.fraction, closeTo(1 / 3, 0.001));
      expect(finishing.fraction, 1);
    });

    test('subdivides the upload stage by photo count', () {
      // A five-photo registration must visibly move rather than sit still on
      // one long step.
      const none = DepotSubmitProgress(
          stage: SubmitStage.uploadingPhotos, photosTotal: 4);
      const half = DepotSubmitProgress(
          stage: SubmitStage.uploadingPhotos, photosSent: 2, photosTotal: 4);
      const all = DepotSubmitProgress(
          stage: SubmitStage.uploadingPhotos, photosSent: 4, photosTotal: 4);

      expect(none.fraction, closeTo(2 / 3, 0.001));
      expect(half.fraction, closeTo(2 / 3 + (1 / 3) * 0.5, 0.001));
      expect(all.fraction, closeTo(1, 0.001));
    });

    test('no photos does not divide by zero', () {
      const progress = DepotSubmitProgress(stage: SubmitStage.uploadingPhotos);

      expect(progress.hasPhotos, isFalse);
      expect(progress.fraction, closeTo(2 / 3, 0.001));
      expect(progress.fraction.isNaN, isFalse);
    });

    test('the fraction never leaves 0..1', () {
      for (final stage in SubmitStage.values) {
        for (final sent in [0, 1, 3]) {
          final f = DepotSubmitProgress(
                  stage: stage, photosSent: sent, photosTotal: 3)
              .fraction;
          expect(f, inInclusiveRange(0, 1), reason: '$stage $sent/3');
        }
      }
    });
  });

  group('the dialog', () {
    Future<void> pump(WidgetTester tester, DepotSubmitProgress progress) async {
      // A phone-sized surface. The default 800x600 test window makes the
      // responsive helpers scale against a design size of 390x844 and produces
      // sizes no real handset ever renders.
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      return tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: DepotSubmitProgressDialog(progress: progress),
        ),
      ));
    }

    testWidgets('never claims the record is going to SAP now', (tester) async {
      await pump(
          tester, const DepotSubmitProgress(stage: SubmitStage.registering));
      await tester.pump();

      // The only mention of the ERP is the footnote saying the wait is not
      // the rep's. No stage may be phrased as an in-flight ERP call.
      expect(find.textContaining('Sending to SAP'), findsNothing);
      expect(find.textContaining('Uploading to SAP'), findsNothing);
      expect(
        find.textContaining('Delivery to SAP happens later'),
        findsOneWidget,
      );
    });

    testWidgets('shows the real stages', (tester) async {
      await pump(
          tester, const DepotSubmitProgress(stage: SubmitStage.registering));
      await tester.pump();

      expect(find.text('Checking the form'), findsOneWidget);
      expect(find.text('Saving to the server'), findsOneWidget);
      expect(find.text('Finishing up'), findsOneWidget);
    });

    testWidgets('hides the photo stage when nothing was attached',
        (tester) async {
      await pump(
          tester, const DepotSubmitProgress(stage: SubmitStage.registering));
      await tester.pump();

      // An instant 0/0 row is noise, not information.
      expect(find.textContaining('Uploading photos'), findsNothing);
    });

    testWidgets('counts photos as they land', (tester) async {
      await pump(
        tester,
        const DepotSubmitProgress(
          stage: SubmitStage.uploadingPhotos,
          photosSent: 2,
          photosTotal: 5,
        ),
      );
      await tester.pump();

      expect(find.text('Uploading photos (2 of 5)'), findsOneWidget);
    });

    testWidgets('the progress bar is determinate, not an endless spinner',
        (tester) async {
      await pump(
          tester, const DepotSubmitProgress(stage: SubmitStage.registering));
      await tester.pump();

      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, isNotNull,
          reason: 'an indeterminate bar on a multi-photo upload is '
              'indistinguishable from a hang');
      expect(bar.value, closeTo(1 / 3, 0.001));
    });

    testWidgets('cannot be dismissed with the back gesture', (tester) async {
      await pump(
          tester, const DepotSubmitProgress(stage: SubmitStage.registering));
      await tester.pump();

      // The create request is already in flight and half of it cannot be
      // recalled, so leaving mid-submit must not be offered.
      final scope = tester.widget<PopScope>(find.byType(PopScope));
      expect(scope.canPop, isFalse);
    });

    testWidgets('the last stage does not render as still working',
        (tester) async {
      await pump(
          tester, const DepotSubmitProgress(stage: SubmitStage.finishing));
      await tester.pump();

      // Everything is done by the time `finishing` is emitted; a spinner here
      // would leave the dialog looking stuck as it closes.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
