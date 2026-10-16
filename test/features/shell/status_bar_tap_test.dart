import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the shell crash in isolation, then pins the fix.
///
/// `Scaffold` binds a status-bar tap to `primaryScrollController.animateTo(0)`,
/// and `ScrollController.animateTo` drives **every attached position**, not
/// just the visible one. The shell attaches several at once: `IndexedStack`
/// keeps every built tab in the tree, and the home tab's `AnimatedSwitcher`
/// holds the guest and authenticated lists together during a sign-in.
///
/// A position that has not completed layout has a null `minScrollExtent`, and
/// `BouncingScrollPhysics.createBallisticSimulation` reads it through
/// `outOfRange` — "Null check operator used on a null value".
void main() {
  /// Mirrors the shell: a stack of lists, only one of them on screen.
  Widget stackOfTabs({required bool scoped}) {
    const stack = IndexedStack(
      index: 0,
      children: [
        _Tab(label: 'visible'),
        _Tab(label: 'offscreen'),
      ],
    );

    return MaterialApp(
      home: Scaffold(
        body: scoped ? const PrimaryScrollController.none(child: stack) : stack,
      ),
    );
  }

  /// What `ScaffoldState.handleStatusBarTap` does.
  Future<void> tapStatusBar(WidgetTester tester) async {
    final controller = PrimaryScrollController.maybeOf(
      tester.element(find.byType(IndexedStack)),
    );
    if (controller == null || !controller.hasClients) return;
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  testWidgets('unscoped, several positions attach to one controller',
      (tester) async {
    // The precondition for the crash. Both lists claim the primary controller,
    // so a single animateTo drives both.
    await tester.pumpWidget(stackOfTabs(scoped: false));

    final controller = PrimaryScrollController.maybeOf(
      tester.element(find.byType(IndexedStack)),
    );
    expect(controller?.positions.length, greaterThan(1),
        reason: 'this is what makes the status-bar tap dangerous');
  });

  testWidgets('scoped out, the shell exposes no clients to animate',
      (tester) async {
    await tester.pumpWidget(stackOfTabs(scoped: true));

    final controller = PrimaryScrollController.maybeOf(
      tester.element(find.byType(IndexedStack)),
    );
    expect(controller?.hasClients ?? false, isFalse);

    // The tap becomes a no-op rather than a crash.
    await tapStatusBar(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scope does not stop a tab scrolling', (tester) async {
    // Losing scroll-to-top is the accepted cost; losing scrolling would not be.
    await tester.pumpWidget(stackOfTabs(scoped: true));

    await tester.drag(find.text('visible 0'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(IndexedStack), findsOneWidget);
  });

  testWidgets('switching tabs does not remount them', (tester) async {
    // The regression an earlier fix introduced: wrapping only the hidden tabs
    // changed tree depth on every switch, remounting the tab and destroying
    // the state `IndexedStack` exists to preserve.
    var initCount = 0;
    var index = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: PrimaryScrollController.none(
              child: IndexedStack(
                index: index,
                children: [
                  _CountingTab(onInit: () => initCount++),
                  const _Tab(label: 'other'),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => setState(() => index = index == 0 ? 1 : 0),
              child: const Icon(Icons.swap_horiz),
            ),
          ),
        ),
      ),
    );

    expect(initCount, 1);

    // Away and back.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(initCount, 1, reason: 'the tab must survive the round trip');
  });
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // `primary` left unset and physics bouncing, exactly as the shell's tabs
    // are — that combination is what reads `minScrollExtent`.
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: 40,
      itemBuilder: (_, i) => SizedBox(height: 60, child: Text('$label $i')),
    );
  }
}

/// A tab that counts how many times its State was created.
class _CountingTab extends StatefulWidget {
  const _CountingTab({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_CountingTab> createState() => _CountingTabState();
}

class _CountingTabState extends State<_CountingTab> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: 20,
        itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
      );
}
