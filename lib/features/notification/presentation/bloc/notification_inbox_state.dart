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
    this.errorMessage,
    this.actionInFlightId,
  });

  final NotificationQuery query;

  /// Newest first, with items requiring acknowledgement pinned above the rest —
  /// the ordering the DAO applies (§5.4, §6.2).
  final List<NotificationMessage> items;

  final NotificationSyncStatus status;

  /// True once the local stream has delivered at least one snapshot.
  ///
  /// This — not [items] being empty — is what distinguishes "still opening the
  /// database" from "genuinely nothing here". Without it, the empty state
  /// flashes for a frame on every open, which reads as a bug.
  final bool loadedOnce;

  /// A translated, user-safe message for the last failure the rep asked for.
  ///
  /// Only set for actions a human initiated (pull-to-refresh, tapping an action
  /// button). A background catch-up failing sets [status] and nothing else:
  /// interrupting a rep to tell them a sync they did not ask for did not run is
  /// noise.
  final String? errorMessage;

  /// The notification whose inline action is currently running, so its button
  /// can show a spinner and refuse a second tap. One at a time: an `api_call`
  /// action is a real decision, and double-firing "Approve" is not recoverable
  /// by the client.
  final String? actionInFlightId;

  bool get isEmpty => loadedOnce && items.isEmpty;
  bool get isSyncing => status == NotificationSyncStatus.syncing;

  /// The items pinned to the top, for a surface that renders them as their own
  /// group. Derived rather than stored so it cannot drift from [items].
  List<NotificationMessage> get outstanding =>
      items.where((i) => i.isOutstandingAction).toList(growable: false);

  NotificationInboxState copyWith({
    NotificationQuery? query,
    List<NotificationMessage>? items,
    NotificationSyncStatus? status,
    bool? loadedOnce,
    String? errorMessage,
    bool clearError = false,
    String? actionInFlightId,
    bool clearActionInFlight = false,
  }) {
    return NotificationInboxState(
      query: query ?? this.query,
      items: items ?? this.items,
      status: status ?? this.status,
      loadedOnce: loadedOnce ?? this.loadedOnce,
      // Both of these need an explicit clear: `copyWith(errorMessage: null)`
      // cannot be told apart from "leave it alone", and an error banner that
      // never goes away is worse than one that never appears.
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionInFlightId: clearActionInFlight
          ? null
          : (actionInFlightId ?? this.actionInFlightId),
    );
  }

  @override
  List<Object?> get props =>
      [query, items, status, loadedOnce, errorMessage, actionInFlightId];
}
