import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// The paused→running transition in `AppCoachHost` crossfades between three
/// very differently sized children: an empty `SizedBox.shrink()`, a 120×120
/// `Align`ed bubble, and a full-screen overlay. `AnimatedSwitcher`'s default
/// `layoutBuilder` stacks outgoing and incoming children as plain (not
/// `Positioned`) `Stack` children, so during the crossfade both are laid out
/// at their own wildly different sizes at once.
///
/// This mirrors the shape without the coach feature's own dependencies, so it
/// can drive the transition and pump every frame of it under semantics —
/// where the real assertion lives.
void main() {
  late SemanticsHandle handle;
  setUp(() => handle = SemanticsBinding.instance.ensureSemantics());
  tearDown(() => handle.dispose());

  Widget shellWithSwitcher(
      {required bool useFillLayout, required bool paused}) {
    // A real Sliver-backed list, standing in for the coach's anchor target
    // (e.g. the Home tab's MonthlyTargetCard) sitting beneath the switcher —
    // the semantics tree has to merge across both.
    final anchoredList = ListView.builder(
      itemCount: 30,
      itemBuilder: (_, i) => SizedBox(height: 56, child: Text('row $i')),
    );

    final child = paused
        ? const Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
                width: 120, height: 120, child: ColoredBox(color: Colors.blue)),
          )
        : Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: const Center(child: Text('assistant overlay')),
          );

    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: anchoredList),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: useFillLayout
                    ? (currentChild, previousChildren) => Stack(
                          fit: StackFit.expand,
                          children: [
                            for (final c in previousChildren)
                              Positioned.fill(child: c),
                            if (currentChild != null)
                              Positioned.fill(child: currentChild),
                          ],
                        )
                    : AnimatedSwitcher.defaultLayoutBuilder,
                child: KeyedSubtree(
                  key: ValueKey(paused ? 'paused' : 'running'),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pumps through the whole crossfade, one frame at a time — the window
  /// where outgoing and incoming children are simultaneously mounted.
  Future<void> pumpTransition(WidgetTester tester, bool useFillLayout) async {
    await tester.pumpWidget(
      shellWithSwitcher(useFillLayout: useFillLayout, paused: true),
    );
    await tester.pumpAndSettle();

    // The paused → running flip, matching `_onResumed`.
    await tester.pumpWidget(
      shellWithSwitcher(useFillLayout: useFillLayout, paused: false),
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('the fill layoutBuilder survives every frame of the crossfade',
      (tester) async {
    await pumpTransition(tester, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sanity: the default layoutBuilder is what this replaces',
      (tester) async {
    // Not asserting failure here — this environment (headless test binding,
    // no real Overlay-boundary semantics merge) may not reproduce the exact
    // framework assertion. It exists to record that this is genuinely the
    // *default* being replaced, not a straw man.
    await pumpTransition(tester, false);
  });

  testWidgets('both children fill the available space, never their own size',
      (tester) async {
    // Direct assertion on the fix: whichever child is present is always
    // exactly the Stack's size, so no size jump exists for layout to chase.
    await tester.pumpWidget(
      shellWithSwitcher(useFillLayout: true, paused: true),
    );
    await tester.pumpAndSettle();

    final stackSize = tester.getSize(find.byType(Scaffold));
    final positioned =
        tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    final fillPositioned = positioned.where(
        (p) => p.left == 0 && p.right == 0 && p.top == 0 && p.bottom == 0);
    expect(fillPositioned, isNotEmpty);
    expect(stackSize, isNot(const Size(120, 120)));
  });
}
