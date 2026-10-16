import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/my_visits/domain/services/check_in_location_verifier.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/check_in_confirmation_dialog.dart';

/// The dialog decides whether a durable, non-reversible check-in gets written.
///
/// Two rules with teeth:
///
/// * Inside the area, **Confirm Check-In** proceeds with no reason asked.
/// * Outside it the rep is **not blocked** — the action becomes **Continue with
///   Reason**, and `Confirm Check-In` is *absent*, not disabled. A greyed-out
///   primary action reads as "this ought to work"; the forward path here is a
///   different one, not the same one withheld.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    await LocalizationService.instance.load('en');
  });

  Future<CheckInConfirmation?> pump(
    WidgetTester tester,
    CheckInLocationVerdict verdict, {
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    CheckInConfirmation? result;

    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Builder(
            builder: (inner) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      result = await CheckInConfirmationDialog.show(
                    inner,
                    outletName: 'ISI Steel Outlet',
                    verdict: verdict,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  group('within the check-in radius', () {
    const within =
        CheckInLocationVerdict.within(distanceMeters: 85, radiusMeters: 100);

    testWidgets('states the verdict, the outlet, and both figures',
        (tester) async {
      await pump(tester, within);

      expect(find.text('Within Check-In Radius'), findsOneWidget);
      expect(find.text('ISI Steel Outlet'), findsOneWidget);
      expect(find.text('Distance from outlet'), findsOneWidget);
      expect(find.text('85 m'), findsOneWidget);
      expect(find.text('Allowed radius'), findsOneWidget);
      expect(find.text('100 m'), findsOneWidget);
    });

    testWidgets('offers Cancel and Confirm Check-In', (tester) async {
      await pump(tester, within);

      expect(find.text('Confirm Check-In'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Inside the area, nothing is asked beyond confirming.
      expect(find.text('Continue with Reason'), findsNothing);
    });

    testWidgets('Confirm returns confirmed', (tester) async {
      final result = await pump(tester, within);
      expect(result, isNull, reason: 'not chosen yet');

      await tester.tap(find.text('Confirm Check-In'));
      await tester.pumpAndSettle();
      // The dialog closed with a decision.
      expect(find.text('Within Check-In Radius'), findsNothing);
    });
  });

  group('outside the check-in radius', () {
    const outside =
        CheckInLocationVerdict.outside(distanceMeters: 250, radiusMeters: 100);

    testWidgets('states the verdict and the distance', (tester) async {
      await pump(tester, outside);

      expect(find.text('Outside Check-In Radius'), findsOneWidget);
      expect(find.text('250 m'), findsOneWidget);
      expect(find.textContaining('a reason is required'), findsOneWidget);
    });

    testWidgets('offers a reasoned path, never a bare confirm', (tester) async {
      await pump(tester, outside);

      // The rule this file exists for: the rep may proceed, but not silently.
      expect(find.text('Confirm Check-In'), findsNothing);
      expect(find.text('Continue with Reason'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Continue with Reason returns withReason', (tester) async {
      await pump(tester, outside);

      await tester.tap(find.text('Continue with Reason'));
      await tester.pumpAndSettle();

      // The caller collects the reason next; this value alone checks nobody in.
      expect(find.text('Outside Check-In Radius'), findsNothing);
    });
  });

  group('the outcomes with nothing to measure', () {
    testWidgets('no GPS fix asks the rep to wait, not to move', (tester) async {
      await pump(
          tester, const CheckInLocationVerdict.noDeviceFix(radiusMeters: 100));

      expect(find.text('Locating You'), findsOneWidget);
      expect(find.text('Confirm Check-In'), findsNothing,
          reason: 'never confirmable without a position');
      expect(find.text('Continue with Reason'), findsNothing,
          reason: 'nothing measured, so there is no rule to reason past');
      // No distance block at all — NaN must never reach the screen.
      expect(find.text('Distance from outlet'), findsNothing);
      expect(find.textContaining('NaN'), findsNothing);
    });

    testWidgets('an outlet with no pin says so', (tester) async {
      await pump(tester,
          const CheckInLocationVerdict.noOutletLocation(radiusMeters: 100));

      expect(find.text('Outlet Location Unavailable'), findsOneWidget);
      expect(find.text('Confirm Check-In'), findsNothing);
      expect(find.text('Continue with Reason'), findsNothing);
      expect(find.textContaining('NaN'), findsNothing);
    });
  });

  group('presentation rules', () {
    testWidgets('distance renders as whole metres', (tester) async {
      await pump(
          tester,
          const CheckInLocationVerdict.within(
              distanceMeters: 84.6231, radiusMeters: 100));

      // A rep does not need centimetres.
      expect(find.text('85 m'), findsOneWidget);
      expect(find.textContaining('84.6'), findsNothing);
    });

    testWidgets('does not overflow at 200% text scale', (tester) async {
      // FS-A11Y-2. A clipped primary action on a decision dialog is not
      // cosmetic — it is a rep unable to confirm a visit.
      await pump(
          tester,
          const CheckInLocationVerdict.within(
              distanceMeters: 85, radiusMeters: 100),
          textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.text('Confirm Check-In'), findsOneWidget);
    });

    testWidgets('leaks no translation keys', (tester) async {
      await pump(
          tester,
          const CheckInLocationVerdict.outside(
              distanceMeters: 250, radiusMeters: 100));

      final leaked = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((s) => s.startsWith('my_visits.') || s.startsWith('common.'))
          .toList();
      expect(leaked, isEmpty);
    });
  });

  group('in Khmer', () {
    setUp(() => LocalizationService.instance.load('km'));
    tearDown(() => LocalizationService.instance.load('en'));

    testWidgets('renders Khmer copy and still fits at 200%', (tester) async {
      await pump(
          tester,
          const CheckInLocationVerdict.within(
              distanceMeters: 85, radiusMeters: 100),
          textScale: 2.0);

      expect(find.text('Within Check-In Radius'), findsNothing);
      expect(find.text('នៅក្នុងរង្វង់ចូលបំពេញការងារ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
