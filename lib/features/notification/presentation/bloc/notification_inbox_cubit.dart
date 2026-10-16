import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/notification/domain/entities/notification_action.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/domain/usecases/inbox_usecases.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_state.dart';

/// Drives the notification inbox.
///
/// ## Reads come from a local stream, not from a fetch
///
/// [_subscribe] binds to the repository's Drift-backed stream, so a catch-up, an
/// arriving push and the action queue draining all land on the screen without
/// the screen asking. The network call ([refresh]) only *feeds* that stream —
/// it never populates the state directly. That is what makes the inbox render
/// instantly and identically offline, which
/// `docs/feature/notification/README.md` §1 treats as the whole point.
///
/// ## Reading and acting are different gestures
///
/// [open] marks read; [runAction] records an action. §8.3 is blunt about why
/// they must not be merged: a route assignment that has been *read* still counts
/// against the badge and still escalates to a supervisor if it is never
/// *acknowledged*. Wiring "the rep scrolled past it" to the action call would
/// silently disarm that escalation for every assignment in the system.
class NotificationInboxCubit extends Cubit<NotificationInboxState> {
  NotificationInboxCubit({
    required WatchNotifications watchNotifications,
    required SyncNotifications syncNotifications,
    required MarkNotificationRead markRead,
    required MarkAllNotificationsRead markAllRead,
    required RecordNotificationAction recordAction,
    required DismissNotification dismissNotification,
    required Future<void> Function({
      required String endpoint,
      required String method,
    }) invokeAction,
  })  : _watch = watchNotifications,
        _sync = syncNotifications,
        _markRead = markRead,
        _markAllRead = markAllRead,
        _recordAction = recordAction,
        _dismiss = dismissNotification,
        _invokeAction = invokeAction,
        super(const NotificationInboxState());

  final WatchNotifications _watch;
  final SyncNotifications _sync;
  final MarkNotificationRead _markRead;
  final MarkAllNotificationsRead _markAllRead;
  final RecordNotificationAction _recordAction;
  final DismissNotification _dismiss;

  /// Runs an action's own `method endpoint` (§12).
  ///
  /// Injected as a function rather than a use case because it is not a
  /// notification business action at all — it is a call into *another* feature's
  /// endpoint, chosen by the server. Wrapping it in a `RunNotificationAction`
  /// use case would imply the notification domain owns route acknowledgement and
  /// quotation approval, which it does not.
  final Future<void> Function(
      {required String endpoint, required String method}) _invokeAction;

  StreamSubscription<List<NotificationMessage>>? _subscription;

  /// Opens the stream and kicks off a catch-up.
  ///
  /// Both, every time: §6.1 lists app start and screen open among the moments to
  /// catch up, and the stream alone would show whatever was last synced without
  /// ever asking for more.
  void start() {
    _subscribe(state.query);
    unawaited(refresh());
  }

  /// Switches tab — inbox, action needed, or history.
  void setScope(NotificationScope scope) {
    if (state.query.scope == scope) return;
    final query = state.query.copyWith(scope: scope);
    emit(state.copyWith(query: query, loadedOnce: false, clearError: true));
    _subscribe(query);
  }

  /// Filters by category, or clears the filter when [category] is null.
  ///
  /// Purely local — the mirror already holds every category, so a chip tap costs
  /// no round trip and works identically offline.
  void setCategory(NotificationCategory? category) {
    if (state.query.category == category) return;
    final query = category == null
        ? state.query.copyWith(clearCategory: true)
        : state.query.copyWith(category: category);
    emit(state.copyWith(query: query, clearError: true));
    _subscribe(query);
  }

  /// Pull-to-refresh, and the app-resume path.
  ///
  /// Unlike a background catch-up, this reports a failure: a human explicitly
  /// asked, and leaving them staring at a spinner that resolves to nothing is
  /// how a rep concludes the app is broken.
  Future<void> refresh() async {
    emit(state.copyWith(
      status: NotificationSyncStatus.syncing,
      clearError: true,
    ));

    final result = await _sync(SyncNotificationsParams.delta);
    if (isClosed) return;

    emit(result.when(
      success: (_) => state.copyWith(status: NotificationSyncStatus.idle),
      failure: (failure) => state.copyWith(
        status: NotificationSyncStatus.failed,
        errorMessage: _messageFor(failure),
      ),
    ));
  }

  /// The rep opened a notification. Marks it read — and nothing more.
  Future<void> open(NotificationMessage notification) async {
    if (!notification.isUnread) return;
    // The result is intentionally unexamined. The local mirror has already
    // changed and the server call is queued; a network failure here is not
    // something to put in front of somebody who just tapped a list row.
    await _markRead(notification.id);
  }

  /// Clears everything the rep can currently see.
  ///
  /// Scoped to the active category filter, per §8.2 — the button must clear what
  /// is on screen, not what is behind a filter they cannot see.
  Future<void> markAllRead() async {
    final result = await _markAllRead(
      MarkAllNotificationsReadParams(
        categoryCode: state.query.category?.code,
      ),
    );
    if (isClosed) return;
    result.when(
      success: (_) {},
      failure: (failure) =>
          emit(state.copyWith(errorMessage: _messageFor(failure))),
    );
  }

  /// Swipes a notification away.
  ///
  /// Refused for an item requiring acknowledgement, matching the server's 409 —
  /// so the row never vanishes and reappears (§5.4).
  Future<void> dismiss(NotificationMessage notification) async {
    final result = await _dismiss(notification.id);
    if (isClosed) return;
    result.when(
      success: (_) {},
      failure: (failure) =>
          emit(state.copyWith(errorMessage: _messageFor(failure))),
    );
  }

  /// Runs one of a notification's inline action buttons (§12).
  ///
  /// The order is load-bearing: the action's own endpoint is called **first**,
  /// and only a success is recorded with `POST /action`. Recording first would
  /// mark a route acknowledged whose acknowledgement never reached the route
  /// service — the notification would close, the badge would clear, and the
  /// supervisor's escalation would fire anyway with nothing to explain it.
  ///
  /// [confirmed] is the caller's answer for a `destructive: true` action.
  /// Rejecting a quotation from a lock screen is one mis-tap from a decision
  /// nobody meant to make, so a destructive action that has not been confirmed
  /// does nothing at all rather than proceeding.
  Future<void> runAction(
    NotificationMessage notification,
    NotificationAction action, {
    bool confirmed = false,
  }) async {
    if (action.destructive && !confirmed) return;
    // One at a time. `api_call` actions are real decisions and the client cannot
    // undo a double-fire.
    if (state.actionInFlightId != null) return;

    switch (action.type) {
      case NotificationActionType.deeplink:
        // Navigation is the caller's job — see `NotificationCoordinator`'s note
        // on why nothing outside a widget touches a Navigator. Opening the
        // record counts as reading it, not as acting on it.
        await open(notification);
        return;

      case NotificationActionType.dismiss:
        await dismiss(notification);
        return;

      case NotificationActionType.apiCall:
        break;
    }

    final endpoint = action.endpoint;
    // `NotificationAction.isExecutable` already filtered these out in the
    // mapper, so reaching here means the contract moved. Doing nothing is right:
    // there is no endpoint to call.
    if (endpoint == null || endpoint.isEmpty) return;

    emit(state.copyWith(
      actionInFlightId: notification.id,
      clearError: true,
    ));

    try {
      await _invokeAction(
        endpoint: endpoint,
        method: action.method ?? 'POST',
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        clearActionInFlight: true,
        // Deliberately generic. The failure came from another feature's
        // endpoint, whose error vocabulary this screen does not know, and
        // guessing at it would put a wrong explanation in front of the rep.
        errorMessage: 'notifications.action_failed'.tr,
      ));
      return;
    }

    final result = await _recordAction(
      RecordNotificationActionParams(
        notificationId: notification.id,
        actionId: action.id,
      ),
    );
    if (isClosed) return;

    emit(result.when(
      success: (_) => state.copyWith(clearActionInFlight: true),
      // The endpoint call succeeded and only the bookkeeping failed. The
      // repository has already queued the `/action` call, so this is
      // self-healing — but a 409 means somebody else decided first and the rep
      // needs telling (§8.5, §13.6).
      failure: (failure) => state.copyWith(
        clearActionInFlight: true,
        errorMessage: failure.statusCode == 409
            ? 'notifications.already_handled'.tr
            : null,
      ),
    ));
  }

  /// Clears the error banner once the rep has seen it.
  void acknowledgeError() {
    if (state.errorMessage == null) return;
    emit(state.copyWith(clearError: true));
  }

  void _subscribe(NotificationQuery query) {
    _subscription?.cancel();
    _subscription = _watch(query).listen((items) {
      if (isClosed) return;
      emit(state.copyWith(items: items, loadedOnce: true));
    });
  }

  /// A translated, user-safe message.
  ///
  /// Client-raised failures carry English literals written for developers, so
  /// they are translated here in the presentation layer where `.tr` belongs.
  /// Server failures keep their message: the API already localised it against
  /// the `Accept-Language` header the app sends on every request.
  String _messageFor(Failure failure) => switch (failure) {
        NetworkFailure() => 'common.no_connection'.tr,
        ServerUnreachableFailure() => 'common.server_unreachable'.tr,
        _ => failure.message,
      };

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
