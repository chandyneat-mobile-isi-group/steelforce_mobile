import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/usecases/inbox_usecases.dart';

/// The badge numbers, for the app bar bell and anything else that shows a count.
///
/// ## Two numbers, two meanings
///
/// `docs/feature/notification/README.md` §5.4 and §7 keep these apart on
/// purpose:
///
///  * **`unread`** drives the bell — "there is something to look at".
///  * **`actionRequired`** drives the app icon — "there is work you owe
///    somebody". A badge counting unread mail says *you have mail*; one counting
///    outstanding actions says *you have work*, and only the second earns an
///    interruption.
///
/// A **read** assignment is still outstanding, so the two numbers legitimately
/// disagree and neither is derivable from the other.
///
/// ## A singleton, not a per-screen factory
///
/// The bell lives in the app bar, which is rebuilt on every tab change, and the
/// inbox sheet shows the same figures. A factory registration would open a fresh
/// Drift stream per rebuild and leak one per discarded app bar; worse, the two
/// surfaces could briefly disagree, which is exactly how a badge stops being
/// believed.
class NotificationBadgeCubit extends Cubit<NotificationCounts> {
  NotificationBadgeCubit({
    required WatchNotificationCounts watchCounts,
    required RefreshNotificationCounts refreshCounts,
  })  : _watch = watchCounts,
        _refresh = refreshCounts,
        super(NotificationCounts.empty);

  final WatchNotificationCounts _watch;
  final RefreshNotificationCounts _refresh;

  StreamSubscription<NotificationCounts>? _subscription;

  /// Binds to the local count stream. Idempotent, because the app bar can
  /// legitimately ask more than once.
  void start() {
    if (_subscription != null) return;
    _subscription = _watch(const NoParams()).listen((counts) {
      if (isClosed) return;
      emit(counts);
    });
  }

  /// Reconciles against `GET /unread-count`.
  ///
  /// §7: cheap enough to call on every foreground, and the only correct source —
  /// a locally incremented counter drifts the first time a push is dropped, and
  /// §1 establishes that dropped pushes are routine rather than exceptional.
  ///
  /// The result is not inspected: this writes through to the local store, which
  /// the stream above is already watching, so the emit happens there. A failure
  /// leaves the last known figures on screen, which is the right answer offline.
  Future<void> reconcile() async {
    await _refresh(const NoParams());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
