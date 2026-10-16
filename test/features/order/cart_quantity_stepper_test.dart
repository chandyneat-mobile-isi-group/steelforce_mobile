import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/cart_quantity_stepper.dart';

void main() {
  late int? lastValue;
  late int writeCount;

  // Mirrors `app.dart`: the whole app runs inside ScreenUtilInit, and the
  // stepper uses the responsive helpers. Without it ScreenUtil's fields are
  // unset and the widget throws LateInitializationError before it renders.
  Widget host({required int quantity}) {
    lastValue = null;
    writeCount = 0;
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: Scaffold(
          body: Center(
            child: CartQuantityStepper(
              quantity: quantity,
              onChanged: (v) {
                lastValue = v;
                writeCount++;
              },
            ),
          ),
        ),
      ),
    );
  }

  Finder plus() => find.byIcon(Icons.add_rounded);
  Finder minus() => find.byIcon(Icons.remove_rounded);

  /// Past the commit debounce, so the cart write has been issued.
  Future<void> settleWrite(WidgetTester tester) =>
      tester.pumpAndSettle(const Duration(milliseconds: 400));

  group('the number moves before the cart does', () {
    testWidgets('a tap updates the display on the same frame', (tester) async {
      // The point of the local value: the rep sees the new number instantly
      // rather than after a database round trip.
      await tester.pumpWidget(host(quantity: 4));
      await tester.tap(plus());
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
      expect(lastValue, isNull, reason: 'the write is still debounced');

      await settleWrite(tester);
      expect(lastValue, 5);
    });

    testWidgets('a burst of taps writes once, with the final value',
        (tester) async {
      // Each write persists a row and rebuilds the product grid, so a ramp
      // from 4 to 7 must not cost three of them.
      await tester.pumpWidget(host(quantity: 4));
      for (var i = 0; i < 3; i++) {
        await tester.tap(plus());
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(find.text('7'), findsOneWidget);
      expect(writeCount, 0, reason: 'still inside the debounce window');

      await settleWrite(tester);
      expect(writeCount, 1);
      expect(lastValue, 7);
    });
  });

  group('increase', () {
    testWidgets('works for a material with no stock figure', (tester) async {
      // The regression that started all of this: a material from the selection
      // API had a zero `availableQuantity` because the API never sent one,
      // that zero was read as a ceiling, and the first `+` tap did nothing.
      await tester.pumpWidget(host(quantity: 0));
      await tester.tap(plus());
      await settleWrite(tester);
      expect(lastValue, 1);
    });

    testWidgets('works from any starting quantity', (tester) async {
      await tester.pumpWidget(host(quantity: 2));
      await tester.tap(plus());
      await settleWrite(tester);
      expect(lastValue, 3);
    });

    testWidgets('is bounded only by the typo guard', (tester) async {
      // Nothing else caps it: not a band, not a unit, not an on-hand figure.
      await tester.pumpWidget(host(quantity: 5));
      await tester.tap(plus());
      await settleWrite(tester);
      expect(lastValue, 6);
    });
  });

  group('decrease', () {
    testWidgets('works from any quantity', (tester) async {
      await tester.pumpWidget(host(quantity: 3));
      await tester.tap(minus());
      await settleWrite(tester);
      expect(lastValue, 2);
    });

    testWidgets('stops at zero', (tester) async {
      await tester.pumpWidget(host(quantity: 0));
      await tester.tap(minus());
      await settleWrite(tester);
      expect(lastValue, isNull);
    });
  });

  group('typing a quantity', () {
    testWidgets('tapping the number opens a field and commits it',
        (tester) async {
      await tester.pumpWidget(host(quantity: 1));

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(lastValue, 250);
    });

    testWidgets('is clamped to the typo guard and nothing else',
        (tester) async {
      await tester.pumpWidget(host(quantity: 1));

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '9999999999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // A `Low` band did not cap it — only the slipped-thumb guard did.
      expect(lastValue, CartQuantityStepper.typoGuard);
    });

    testWidgets('a cleared field changes nothing', (tester) async {
      // Clearing the box and tapping away is a rep abandoning the edit, not an
      // instruction to remove the line.
      await tester.pumpWidget(host(quantity: 7));

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(lastValue, isNull);
    });
  });

  group('state does not leak between rows', () {
    testWidgets('a rebuilt list with a different value adopts it',
        (tester) async {
      // The recycling bug: the stepper now holds a local quantity, so a list
      // that reuses this State for a *different* line must not keep showing
      // the previous line's number. Keys prevent the reuse; this pins the
      // fallback — when the parent hands down a different value and nothing is
      // in flight, the parent wins.
      await tester.pumpWidget(host(quantity: 5));
      expect(find.text('5'), findsOneWidget);

      await tester.pumpWidget(host(quantity: 12));
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('an in-flight edit is not clobbered by a stale echo',
        (tester) async {
      // The other direction: while the write is still debounced, an older
      // value arriving from the parent must not overwrite what the rep just
      // typed.
      await tester.pumpWidget(host(quantity: 5));
      await tester.tap(plus());
      await tester.pump();
      expect(find.text('6'), findsOneWidget);

      // The parent rebuilds still holding the pre-write value.
      await tester.pumpWidget(host(quantity: 5));
      await tester.pump();
      expect(find.text('6'), findsOneWidget,
          reason: 'the local value is the newer of the two');
    });
  });

  group('typing reaches the cart without pressing Done', () {
    testWidgets('a typed value commits while the keyboard is still open',
        (tester) async {
      // The reported bug: the rep typed 800, looked at the cart, and saw 1.
      // The write only happened on Done, so mid-edit the cart legitimately
      // still held the old number — and legitimately looked broken.
      await tester.pumpWidget(host(quantity: 1));
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '800');
      await settleWrite(tester);

      expect(lastValue, 800);
      expect(find.byType(TextField), findsOneWidget,
          reason: 'still editing — the keyboard was never dismissed');
    });

    testWidgets('a burst of keystrokes still writes once', (tester) async {
      await tester.pumpWidget(host(quantity: 0));
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      for (final text in ['8', '80', '800']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(writeCount, 0, reason: 'still inside the debounce window');

      await settleWrite(tester);
      expect(writeCount, 1);
      expect(lastValue, 800);
    });

    testWidgets('clearing the field mid-edit does not zero the line',
        (tester) async {
      // The rep is part-way through replacing the number; blanking the line
      // under them would be its own bug.
      await tester.pumpWidget(host(quantity: 12));
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await settleWrite(tester);

      expect(lastValue, isNull);
    });

    testWidgets('Done does not double-write an already-committed value',
        (tester) async {
      await tester.pumpWidget(host(quantity: 1));
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '45');
      await settleWrite(tester);
      expect(writeCount, 1);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleWrite(tester);

      expect(writeCount, 1, reason: 'the value was already written');
      expect(lastValue, 45);
    });
  });

  group('the buttons and the open field stay in step', () {
    testWidgets('+ while editing moves the number in the field',
        (tester) async {
      // The bug: `+` moved the committed value but the field kept rendering
      // its own stale text, so the number under the caret disagreed with what
      // was being written.
      await tester.pumpWidget(host(quantity: 800));
      await tester.tap(find.text('800'));
      await tester.pumpAndSettle();

      await tester.tap(plus());
      await tester.pump();

      expect(find.text('801'), findsOneWidget);
      await settleWrite(tester);
      expect(lastValue, 801);
    });

    testWidgets('- while editing moves the number in the field',
        (tester) async {
      await tester.pumpWidget(host(quantity: 800));
      await tester.tap(find.text('800'));
      await tester.pumpAndSettle();

      await tester.tap(minus());
      await tester.pump();

      expect(find.text('799'), findsOneWidget);
    });

    testWidgets('stepping then typing keeps the typed value', (tester) async {
      // The controller write-back must not fight the rep's own keystrokes.
      await tester.pumpWidget(host(quantity: 10));
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      await tester.tap(plus());
      await tester.pump();
      expect(find.text('11'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '250');
      await settleWrite(tester);

      expect(lastValue, 250);
    });
  });
}
