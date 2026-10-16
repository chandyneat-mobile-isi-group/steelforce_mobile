import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Verifies the device behaviour [AppBottomSheet] centralises — the logic that
/// was previously copy-pasted into 14 sheets as
/// `EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)`.
///
/// These assert *observable geometry* rather than widget structure: the point is
/// that the last control stays reachable above the keyboard and the home
/// indicator, which is the bug the duplication kept reintroducing.
void main() {
  const homeIndicator = 34.0; // iPhone-style bottom safe inset
  const keyboardHeight = 300.0;

  /// Pumps [child] on a fake device of [size] with the given insets.
  ///
  /// Drives `tester.view` rather than injecting a `MediaQuery`, for two reasons
  /// a hand-rolled harness gets wrong:
  ///  - `MediaQueryData.size` does not resize the render surface, so widgets
  ///    still lay out against the 800×600 default and every width assertion is
  ///    meaningless.
  ///  - `Scaffold` *consumes* bottom `viewInsets` for its body, so a sheet
  ///    inside one reads the keyboard as 0. `Material` is used instead.
  ///
  /// [keyboard] and [bottomPadding] mirror the engine's own contract: when the
  /// keyboard is up it covers the gesture bar, so the platform reports
  /// `padding.bottom == 0`. Passing both non-zero would test a state no device
  /// ever produces.
  Future<void> pumpWithInsets(
    WidgetTester tester, {
    required Widget child,
    double bottomPadding = 0,
    double keyboard = 0,
    Size size = const Size(390, 844),
  }) async {
    const dpr = 1.0;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = size * dpr;
    tester.view.padding = FakeViewPadding(bottom: bottomPadding * dpr);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * dpr);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        // bottomCenter mimics the loose vertical constraints a real modal route
        // gives its child. Under Material's tight constraints the sheet's
        // maxHeight cap could never take effect and the test would prove nothing.
        home: Material(
          child: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens a real modal via [showAppBottomSheet], so route-level config
  /// (width constraints, background, shape) is exercised rather than assumed.
  Future<void> pumpRealSheet(
    WidgetTester tester, {
    required Widget child,
    Size size = const Size(390, 844),
  }) async {
    const dpr = 1.0;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = size * dpr;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppBottomSheet<void>(
                  context: context, builder: (_) => child),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('AppBottomSheet — keyboard', () {
    testWidgets('lifts content above the keyboard', (tester) async {
      await pumpWithInsets(
        tester,
        keyboard: keyboardHeight,
        bottomPadding: homeIndicator,
        child: const AppBottomSheet(
          child: SizedBox(height: 80, child: Text('Save')),
        ),
      );

      final bottom = tester.getRect(find.text('Save')).bottom;

      // The whole point: the control must sit above the keyboard, not under it.
      expect(
        bottom,
        lessThanOrEqualTo(844 - keyboardHeight),
        reason: 'content must clear the keyboard',
      );
    });

    testWidgets('with no keyboard, content still clears the home indicator',
        (tester) async {
      await pumpWithInsets(
        tester,
        bottomPadding: homeIndicator,
        child: const AppBottomSheet(
          child: SizedBox(height: 80, child: Text('Save')),
        ),
      );

      final bottom = tester.getRect(find.text('Save')).bottom;

      expect(
        bottom,
        lessThanOrEqualTo(844 - homeIndicator),
        reason: 'a sheet is drawn over the gesture bar, so it must pad for it',
      );
    });
  });

  group('AppBottomSheet — sizing', () {
    testWidgets('a short sheet stays short instead of stretching',
        (tester) async {
      await pumpWithInsets(
        tester,
        child: const AppBottomSheet(
          showHandle: false,
          child: SizedBox(height: 100, key: Key('body')),
        ),
      );

      // Flexible (not Expanded) is what preserves `mainAxisSize.min` children.
      expect(tester.getSize(find.byKey(const Key('body'))).height, 100);
    });

    testWidgets('tall content is capped and does not overflow', (tester) async {
      await pumpWithInsets(
        tester,
        child: AppBottomSheet(
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(
                60,
                (i) => SizedBox(height: 40, child: Text('row $i')),
              ),
            ),
          ),
        ),
      );

      // A RenderFlex overflow would have been recorded as an exception.
      expect(tester.takeException(), isNull);

      final sheetHeight = tester.getSize(find.byType(AppBottomSheet)).height;
      expect(
        sheetHeight,
        lessThanOrEqualTo(844 * AppBottomSheet.defaultHeightFactor + 1),
        reason: 'the page must stay partly visible so the sheet reads as modal',
      );
    });

    testWidgets('spans the full window on a tablet', (tester) async {
      // Reversed deliberately. This previously asserted a 560pt cap, on the
      // reasoning that a full-width sheet puts Cancel and Save ~700px apart.
      // That holds only for a single narrow column stretched across the screen;
      // the sheets now lay their content out in multiple columns to fill the
      // width (see add_depot_bottom_sheet's all-steps layout), so the width
      // is used rather than merely spanned.
      await pumpRealSheet(
        tester,
        size: const Size(1024, 1366),
        child: const SizedBox(height: 80, key: Key('body')),
      );

      expect(tester.getSize(find.byType(AppBottomSheet)).width, 1024);
    });

    testWidgets('is full-width on a phone', (tester) async {
      await pumpRealSheet(
        tester,
        child: const SizedBox(height: 80, key: Key('body')),
      );

      expect(tester.getSize(find.byType(AppBottomSheet)).width, 390);
    });
  });

  group('DeviceInsets', () {
    testWidgets('reports the keyboard when open', (tester) async {
      late DeviceInsetsData insets;
      await pumpWithInsets(
        tester,
        keyboard: keyboardHeight,
        child: Builder(builder: (context) {
          insets = context.deviceInsets;
          return const SizedBox();
        }),
      );

      expect(insets.keyboard, keyboardHeight);
      expect(insets.isKeyboardOpen, isTrue);
    });

    testWidgets('reports the safe area when the keyboard is closed',
        (tester) async {
      late DeviceInsetsData insets;
      await pumpWithInsets(
        tester,
        bottomPadding: homeIndicator,
        child: Builder(builder: (context) {
          insets = context.deviceInsets;
          return const SizedBox();
        }),
      );

      expect(insets.isKeyboardOpen, isFalse);
      expect(insets.safeBottom, homeIndicator);
    });

    testWidgets('detects tablets by shortest side', (tester) async {
      late DeviceInsetsData phone;
      await pumpWithInsets(
        tester,
        child: Builder(builder: (context) {
          phone = context.deviceInsets;
          return const SizedBox();
        }),
      );
      expect(phone.isTablet, isFalse);

      late DeviceInsetsData tablet;
      await pumpWithInsets(
        tester,
        // Landscape tablet: width alone would misjudge a landscape phone, which
        // is why shortestSide is the test.
        size: const Size(1366, 1024),
        child: Builder(builder: (context) {
          tablet = context.deviceInsets;
          return const SizedBox();
        }),
      );
      expect(tablet.isTablet, isTrue);
    });

    testWidgets('scrollBottomInset adds app chrome on top of the safe area',
        (tester) async {
      late DeviceInsetsData insets;
      await pumpWithInsets(
        tester,
        bottomPadding: homeIndicator,
        child: Builder(builder: (context) {
          insets = context.deviceInsets;
          return const SizedBox();
        }),
      );

      expect(insets.scrollBottomInset(extra: 56), homeIndicator + 56);
    });
  });
}
