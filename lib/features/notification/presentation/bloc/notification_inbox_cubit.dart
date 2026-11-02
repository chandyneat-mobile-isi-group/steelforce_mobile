import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/domain/usecases/inbox_usecases.dart';
import 'package:steelforce/features/notification/domain/usecases/load_older_notifications.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_state.dart';

/// Drives the notification inbox: All or Unread, newest first.
///
/// ## Reads come from a local stream, not from a fetch
///
/// [_subscribe] binds to the repository's Drift-backed stream, so a catch-up,
/// an arriving push and the read queue draining all land on the screen without
/// the screen asking. The network calls ([refresh], [loadMore]) only *feed*
/// that stream — rows are upserted by id, so a page fetched twice never shows
/// a row twice. That is what makes the inbox render instantly and identically
/// offline (`docs/feature/notification/README.md` §1).
class NotificationInboxCubit extends Cubit<NotificationInboxState> {
  NotificationInboxCubit({
    required WatchNotifications watchNotifications,
    required SyncNotifications syncNotifications,
    required LoadOlderNotifications loadOlder,
    required MarkNotificationRead markRead,
    required MarkAllNotificationsRead markAllRead,
  })  : _watch = watchNotifications,
        _sync = syncNotifications,
        _loadOlder = loadOlder,
        _markRead = markRead,
        _markAllRead = markAllRead,
        super(const NotificationInboxState());

  final WatchNotifications _watch;
  final SyncNotifications _sync;
  final LoadOlderNotifications _loadOlder;
  final MarkNotificationRead _markRead;
  final MarkAllNotificationsRead _markAllRead;

  StreamSubscription<List<NotificationMessage>>? _subscription;

  /// Opens the stream and kicks off a catch-up — both, every time: the stream
  /// alone would show whatever was last synced without ever asking for more.
  void start() {
    _subscribe(state.query);
    unawaited(refresh());
  }

  /// Switches between All and Unread. Purely local: the mirror already holds
  /// what was synced, so the switch works offline; [loadMore] then pages the
  /// server for that list.
  void setScope(NotificationScope scope) {
    if (state.query.scope == scope) return;
    final query = NotificationQuery(scope: scope);
    emit(state.copyWith(
      query: query,
      loadedOnce: false,
      hasMore: true,
      clearError: true,
    ));
    _subscribe(query);
  }

  /// Pull-to-refresh, retry, and the app-resume path.
  ///
  /// Unlike a background catch-up, this reports a failure: a human asked.
  Future<void> refresh() async {
    emit(state.copyWith(
      status: NotificationSyncStatus.syncing,
      clearError: true,
    ));

    final result = await _sync(SyncNotificationsParams.delta);
    if (isClosed) return;

    emit(result.when(
      success: (_) => state.copyWith(
          status: NotificationSyncStatus.idle, pagingFailed: false),
      failure: (failure) => state.copyWith(
        status: NotificationSyncStatus.failed,
        errorMessage: _messageFor(failure),
      ),
    ));
  }

  /// The end of the list was reached: show more of the mirror and page the
  /// server for the next older page. Ignored while a page is loading, once the
  /// server said there are no more, and after a failure until [retry] — so a
  /// fast scroll sends one request.
  Future<void> loadMore({bool retry = false}) async {
    if (state.loadingMore || !state.hasMore) return;
    if (state.pagingFailed && !retry) return;
    final query =
        state.query.copyWith(limit: state.query.limit + NotificationQuery.page);
    emit(state.copyWith(query: query, loadingMore: true, clearError: true));
    _subscribe(query);

    final result =
        await _loadOlder(state.query.scope == NotificationScope.unread);
    if (isClosed) return;

    emit(result.when(
      success: (more) => state.copyWith(
          loadingMore: false, hasMore: more, pagingFailed: false),
      failure: (failure) => state.copyWith(
        loadingMore: false,
        pagingFailed: true,
        errorMessage: _messageFor(failure),
      ),
    ));
  }

  /// The rep opened a notification: mark it read.
  ///
  /// The mirror changes at once and the server call is queued (ADR-006) and
  /// retried until it lands, so a network failure is not put in front of
  /// somebody who just tapped a row.
  Future<void> open(NotificationMessage notification) async {
    if (!notification.isUnread) return;
    await _markRead(notification.id);
  }

  /// Marks everything read, locally at once and on the server through the
  /// queue, then says how many were cleared.
  Future<void> markAllRead() async {
    final result = await _markAllRead(const MarkAllNotificationsReadParams());
    if (isClosed) return;
    emit(result.when(
      success: (marked) => state.copyWith(
        notice: marked == 0
            ? 'notifications.all_read_already'.tr
            : 'notifications.marked_read'.trParams({'n': '$marked'}),
      ),
      failure: (failure) => state.copyWith(errorMessage: _messageFor(failure)),
    ));
  }

  /// Clears the snackbar message once the rep has seen it.
  void acknowledgeError() {
    if (state.errorMessage == null && state.notice == null) return;
    emit(state.copyWith(clearError: true));
  }

  void _subscribe(NotificationQuery query) {
    _subscription?.cancel();
    _subscription = _watch(query).listen((items) {
      if (isClosed) return;
      emit(state.copyWith(items: items, loadedOnce: true));
    });
  }

  /// Client-raised failures carry developer English, so they are translated
  /// here; a server failure's message was already localised by the API.
  String _messageFor(Failure failure) => switch (failure) {
        NetworkFailure() => 'common.no_connection'.tr,
        ServerUnreachableFailure() => 'common.server_unreachable'.tr,
        _ => failure.userMessage,
      };

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
