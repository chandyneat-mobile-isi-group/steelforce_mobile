import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_push_summary.dart';
import 'package:steelforce/features/my_visits/domain/usecases/complete_visit_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/usecases/push_pending_visit_data.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/end_visit.dart';

/// "Complete Visit" ends the visit *and* drains the outbound queue.
///
/// The ordering is the whole point of these tests. The push builds its batch
/// from rows already committed to the database, so a check-out still in flight
/// misses the very push its own button triggered. Both call sites used to fire
/// the check-out with `unawaited`, which is exactly the shape that loses that
/// race — and it is invisible in review, because the code "obviously" does both
/// things.
class _RecordingCheckOut implements CompleteVisitCheckOut {
  _RecordingCheckOut(this.log, {this.delay = Duration.zero});

  final List<String> log;

  /// A real check-out is a Drift transaction, not an instant return. The delay
  /// is what makes a fire-and-forget regression actually fail this test rather
  /// than passing on microtask ordering.
  final Duration delay;

  @override
  ResultFuture<bool> call(CheckOutChoice? params) async {
    await Future<void>.delayed(delay);
    log.add('checkout');
    return const Success(true);
  }
}

/// No checked-in visit to describe, so the check-out sheet is skipped and
/// these tests stay about ordering. The sheet has its own tests.
class _NoVisitToDescribe implements GetCheckOutContext {
  @override
  ResultFuture<CheckOutContext?> call(NoParams params) async =>
      const Success(null);
}

class _RecordingPush implements PushPendingVisitData {
  _RecordingPush(this.log, {this.result});

  final List<String> log;
  final Result<VisitPushSummary>? result;

  @override
  ResultFuture<VisitPushSummary> call(NoParams params) async {
    log.add('push');
    return result ??
        Success(VisitPushSummary(pushedCount: 3, syncedAt: DateTime.utc(2026)));
  }
}

void main() {
  late List<String> log;

  void register(
      {Duration checkOutDelay = Duration.zero,
      Result<VisitPushSummary>? pushResult}) {
    GetIt.instance
      ..registerSingleton<GetCheckOutContext>(_NoVisitToDescribe())
      ..registerSingleton<CompleteVisitCheckOut>(
          _RecordingCheckOut(log, delay: checkOutDelay))
      ..registerSingleton<PushPendingVisitData>(
          _RecordingPush(log, result: pushResult));
  }

  setUp(() async {
    log = [];
    // `reset` is async; not awaiting it lets the registration below land and
    // then be wiped by the pending reset.
    await GetIt.instance.reset();
  });
  tearDown(() async => GetIt.instance.reset());

  /// Pumps a two-route stack so `popUntil(isFirst)` has something to pop, and
  /// returns once the button has been tapped.
  Future<NavigatorState> tapCompleteVisit(WidgetTester tester) async {
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: const Scaffold(body: Text('home')),
    ));

    navKey.currentState!.push(MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => endVisitAndSync(context),
            child: const Text('Complete Visit'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Complete Visit'));
    return navKey.currentState!;
  }

  testWidgets('commits the check-out before it pushes', (tester) async {
    register(checkOutDelay: const Duration(milliseconds: 50));
    await tapCompleteVisit(tester);
    await tester.pumpAndSettle();

    // Not just "both ran" — this exact order. Reversed, the check-out this
    // button created would sit pending until some later sync.
    expect(log, ['checkout', 'push']);
  });

  testWidgets('does not push before the check-out has landed', (tester) async {
    register(checkOutDelay: const Duration(milliseconds: 200));
    await tapCompleteVisit(tester);

    // Mid-flight: the check-out is still running, so nothing may have been
    // pushed yet.
    await tester.pump(const Duration(milliseconds: 50));
    expect(log, isEmpty, reason: 'pushed while the check-out was in flight');

    await tester.pumpAndSettle();
    expect(log, ['checkout', 'push']);
  });

  testWidgets('leaves the visit stack without waiting for the network',
      (tester) async {
    register();
    final navigator = await tapCompleteVisit(tester);
    await tester.pumpAndSettle();

    // Back to the first route: the rep is out of the guided-visit stack.
    expect(navigator.canPop(), isFalse);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('lands on the Home tab, whatever tab the visit began on',
      (tester) async {
    register();
    final tabs = ShellTabController()..goTo(ShellTab.myVisits);
    GetIt.instance.registerSingleton<ShellTabController>(tabs);

    await tapCompleteVisit(tester);
    await tester.pumpAndSettle();

    expect(tabs.value, ShellTab.home);
  });

  testWidgets('a failed push does not throw or block the exit', (tester) async {
    // Offline is the normal case, not an error state: the repository answers
    // NetworkFailure without leaving the device and every row stays pending.
    register(pushResult: const Failed(NetworkFailure()));

    final navigator = await tapCompleteVisit(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(log, ['checkout', 'push']);
    // The visit is still complete and the rep is still out.
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('pushes exactly once per tap', (tester) async {
    register();
    await tapCompleteVisit(tester);
    await tester.pumpAndSettle();

    expect(log.where((e) => e == 'push').length, 1);
    expect(log.where((e) => e == 'checkout').length, 1);
  });
}
