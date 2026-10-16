import 'dart:async';

/// Ambient facts about the drain in progress, readable by any outbox without
/// widening the [UnsentWorkSource] contract for every feature.
abstract final class SyncRunContext {
  static const Symbol _deadline = #isi.sync.deadline;

  /// The slowest single request a drain may start: a depot registration's
  /// 60 s write timeout plus margin.
  static const Duration longestRequest = Duration(seconds: 75);

  /// True inside a run whose time budget cannot cover [longestRequest] — an
  /// iOS background refresh has about 25 s.
  ///
  /// An outbox whose write is **not idempotent** must not start one then: the
  /// OS ends the task mid-request, the answer is lost, and a perfectly sendable
  /// item ends up parked for the rep to check. Idempotent work (visit pushes,
  /// photo uploads to an existing depot) goes ahead regardless.
  static bool get shortBudget => !hasTimeFor(longestRequest);

  /// Whether the run still has [needed] left before its budget ends. Always
  /// true outside a budgeted run (the app in the foreground).
  ///
  /// Checked before **each** non-idempotent request, not once per run: a
  /// backlog of several registrations can use up a budget that covered the
  /// first one comfortably.
  static bool hasTimeFor(Duration needed) {
    final deadline = Zone.current[_deadline];
    if (deadline is! DateTime) return true;
    return !DateTime.now().add(needed).isAfter(deadline);
  }

  /// Runs [body] against a deadline [budget] from now.
  static Future<T> withBudget<T>(Duration budget, Future<T> Function() body) =>
      runZoned(body, zoneValues: {_deadline: DateTime.now().add(budget)});
}
