import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/usecases/complete_visit_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/push_pending_visit_data.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/ask_how_visit_ended.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';

/// "Complete Visit": closes the deferred check-out, returns to Home, and
/// drains the outbound queue to
/// `POST /api/v1/mobile/visits/push`.
///
/// One function rather than two copies, because the Inventory completion
/// screen and the Quotation Builder both end a visit and had already drifted
/// into identical private methods.
///
/// ## The order is load-bearing
///
/// The push builds its batch by reading what is *already* in the database
/// ([VisitSyncRepositoryImpl] queries every `sync_status = 'pending'` row).
/// So the check-out has to be committed before the batch is assembled —
/// otherwise the one row this button exists to produce misses the very push it
/// triggers, and sits pending until something else syncs. Both call sites
/// previously fired the check-out with `unawaited`, which is exactly the shape
/// that loses the race.
///
/// ## The rep never waits for the network
///
/// Navigation happens between the two: the visit is complete the moment the
/// local write lands, and the push runs behind the rep. Sync is opportunistic
/// and never on the critical path — offline, `VisitSyncRepositoryImpl` returns
/// a `NetworkFailure` without leaving the device and every row stays pending
/// for the next attempt.
///
/// A failed push shows the rep nothing: they have already left the screen, and
/// the pending-record count on the dashboard
/// (`my_visits.dashboard.pending_sync`) already says what is still waiting. A
/// snackbar fired at a screen someone is walking away from is noise.
///
/// It is **logged**, though. "I pressed Complete Visit and no POST happened" has
/// several innocent explanations — nothing was pending, the device was offline,
/// the session had expired — and they are indistinguishable from a broken
/// button without a line saying which. Watch for `visit.checkout.*` and
/// `visit.push.*` together: the first says whether anything was queued, the
/// second what happened to it.
///
/// ## The rep says how it ended
///
/// First, the check-out sheet: with an order (which) or without (why). Backing
/// out of it leaves the visit open and the rep where they were. The demo
/// build skips the sheet ([visitEndedWithoutAsking]).
Future<void> endVisitAndSync(BuildContext context) async {
  // Captured before the await — after it, `context` may be gone.
  final navigator = Navigator.of(context);

  // The demo build ends the visit in one tap; live builds ask, because the
  // server needs the rep's answer.
  final decision = DataSourceMode.useMocks
      ? await visitEndedWithoutAsking()
      : await askHowVisitEnded(context);
  if (decision == null) return;

  await sl<CompleteVisitCheckOut>()(decision.choice);

  // The visit is over: land on Home, not on the tab the visit started from.
  // The shell is the first route; switching its tab before popping means
  // the rep never sees the old tab flash past.
  if (sl.isRegistered<ShellTabController>()) {
    sl<ShellTabController>().goTo(ShellTab.home);
  }
  navigator.popUntil((route) => route.isFirst);

  // Fire-and-forget by design. `PushPendingVisitData` returns a `Result` and
  // does not throw, so an unawaited failure cannot reach the zone handler.
  unawaited(_push());
}

Future<void> _push() async {
  final logger = sl.isRegistered<AppLogger>() ? sl<AppLogger>() : null;
  final result = await sl<PushPendingVisitData>()(const NoParams());

  result.when(
    // `pushedCount: 0` is the quiet case worth naming: the queue was empty, so
    // no request was made at all. That is correct behaviour and the single most
    // likely reason a POST never appears in the log.
    success: (summary) => logger?.info('visit.push.finished', fields: {
      'accepted': summary.pushedCount,
      'requestMade': summary.pushedCount > 0,
    }),
    // Offline is a NetworkFailure and never leaves the device; an expired
    // session is an AuthenticationFailure. Both leave every row pending.
    failure: (f) => logger?.warning('visit.push.failed', fields: {
      'failure': f.runtimeType.toString(),
      'message': f.message,
    }),
  );
}
