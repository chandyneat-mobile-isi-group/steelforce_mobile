import 'package:equatable/equatable.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';

/// What the inbox is doing with the network right now.
///
/// Separate from whether there is anything to show, and deliberately so: the
/// local mirror means the list is almost always populated *while* a sync is in
/// flight. Collapsing the two into one "loading" state would blank a screenful
/// of perfectly good notifications every time the app came to the foreground —
/// which is the opposite of what an offline-first inbox is for
/// (`docs/feature/notification/README.md` §1).
enum NotificationSyncStatus {
  /// Nothing in flight.
  idle,

  /// A catch-up is running. The list stays visible underneath.
  syncing,

  /// The last catch-up failed. Not an error screen — a quiet marker, because
  /// the rep is looking at a valid inbox and offline is a normal state
  /// (ADR-002 §4).
  failed,
}

class NotificationInboxState extends Equatable {
  const NotificationInboxState({
    this.query = const NotificationQuery(),
    this.items = const [],
    this.status = NotificationSyncStatus.idle,
    this.loadedOnce = false,
    this.hasMore = true,
    this.loadingMore = false,
    this.pagingFailed = false,
    this.errorMessage,
    this.notice,
  });

  /// All or Unread, and how many rows of it to show.
  final NotificationQuery query;

  /// Newest first — the ordering the DAO applies.
  final List<NotificationMessage> items;

  final NotificationSyncStatus status;

  /// True once the local stream has delivered at least one snapshot.
  ///
  /// This — not [items] being empty — is what distinguishes "still opening the
  /// database" from "genuinely nothing here". Without it, the empty state
  /// flashes for a frame on every open, which reads as a bug.
  final bool loadedOnce;

  /// False once the server answered a null `nextCursor` for this list: there
  /// is nothing older to load.
  final bool hasMore;

  /// An older page is loading. While true, reaching the end again does
  /// nothing — one request per page.
  final bool loadingMore;

  /// The last older page failed. Paging waits for a retry or a refresh
  /// rather than re-asking on every scroll — offline, that would be a request
  /// and a snackbar per frame.
  final bool pagingFailed;

  /// A translated, user-safe message for the last failure the rep asked for.
  ///
  /// Only set for actions a human initiated (pull-to-refresh, load more, mark
  /// all read). A background catch-up failing sets [status] and nothing else.
  final String? errorMessage;

  /// A translated confirmation, such as how many were marked read.
  final String? notice;

  bool get isEmpty => loadedOnce && items.isEmpty;
  bool get isSyncing => status == NotificationSyncStatus.syncing;

  /// Nothing to show because the last refresh failed, not because the inbox
  /// is empty — the two must read differently.
  bool get failedEmpty => isEmpty && status == NotificationSyncStatus.failed;

  NotificationInboxState copyWith({
    NotificationQuery? query,
    List<NotificationMessage>? items,
    NotificationSyncStatus? status,
    bool? loadedOnce,
    bool? hasMore,
    bool? loadingMore,
    bool? pagingFailed,
    String? errorMessage,
    String? notice,
    bool clearError = false,
  }) {
    return NotificationInboxState(
      query: query ?? this.query,
      items: items ?? this.items,
      status: status ?? this.status,
      loadedOnce: loadedOnce ?? this.loadedOnce,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      pagingFailed: pagingFailed ?? this.pagingFailed,
      // `copyWith(errorMessage: null)` cannot be told apart from "leave it
      // alone", hence the explicit clear — which drops the notice too.
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearError ? null : (notice ?? this.notice),
    );
  }

  @override
  List<Object?> get props => [
        query,
        items,
        status,
        loadedOnce,
        hasMore,
        loadingMore,
        pagingFailed,
        errorMessage,
        notice,
      ];
}
