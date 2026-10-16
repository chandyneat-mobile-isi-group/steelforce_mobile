import 'package:equatable/equatable.dart';
import 'package:steelforce/features/notification/domain/entities/notification_action.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';

/// One item in the rep's inbox — the notification itself, not a hint that one
/// exists (`docs/feature/notification/README.md` §5).
///
/// ## The inbox is the system of record
///
/// Every notification is written to the backend's database *before* anything is
/// sent to Firebase, and a push routinely never arrives: a flat battery, a
/// coverage hole, a declined OS permission, an OEM battery optimiser, a rotated
/// FCM token, or simply a P4 that is never pushed at all. So this entity is
/// populated from `GET /mobile/notifications` and merely *accelerated* by
/// `onMessage`. A screen whose only source is the FCM callback shows a rep less
/// than half their work.
///
/// ## Field naming
///
/// The wire representation is `snake_case`, unlike the rest of the API, because
/// the notification object is quoted verbatim in the published specification and
/// in the FCM payload. That translation lives in `NotificationApiMapper`; this
/// entity is ordinary Dart and carries no wire concerns.
class NotificationMessage extends Equatable {
  const NotificationMessage({
    required this.id,
    required this.eventCode,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    required this.state,
    required this.createdAt,
    this.imageUrl,
    this.deepLink,
    this.requiresAck = false,
    this.expiresAt,
    this.groupKey,
    this.badge,
    this.actions = const [],
    this.data = const {},
    this.deliveredAt,
    this.readAt,
    this.actionedAt,
  });

  /// `notification_id`. The upsert key for every local write — a catch-up that
  /// overlaps a push already handled must not produce a second row (§16).
  final String id;

  /// `ROUTE.ASSIGNED`. The stable business-event identity.
  ///
  /// Note the FCM payload also ships `type` (`ROUTE_ASSIGNED`, dots flattened
  /// to underscores) for the same fact; §18 records that both are shipped
  /// pending sign-off. This holds the dotted canonical form, and the mapper
  /// normalises the shorthand into it so nothing downstream has to know.
  final String eventCode;

  final NotificationCategory category;
  final NotificationPriority priority;

  /// Server-localised against `Accept-Language`. Render as-is — never `.tr`.
  final String title;
  final String body;

  final String? imageUrl;

  /// `app://routes/{id}`. **Built by the backend**; §11 forbids assembling one
  /// locally from [data]'s entity type and id. Null is a legitimate value for an
  /// event that points at no single record — treat it as "open the inbox".
  final String? deepLink;

  /// The item belongs in the **Action needed** tab, is pinned to the top, and
  /// cannot be dismissed (`DELETE` answers 409). It stays outstanding until
  /// `POST /action` lands.
  final bool requiresAck;

  final DateTime? expiresAt;

  /// Server-supplied grouping key, e.g. `Assignment:{routeId}`. Used for shade
  /// grouping and collapse behaviour, never for local deduplication — that is
  /// [id]'s job.
  final String? groupKey;

  /// The server's own count of outstanding actionable items at the moment this
  /// notification was raised.
  ///
  /// Kept for the app-icon badge on a push that arrives with no chance to call
  /// `unread-count` first. It is a **snapshot, not a running total**: reconcile
  /// against `GET /unread-count` on every foreground rather than trusting this,
  /// because a badge nobody trusts is a badge everybody ignores (§7).
  final int? badge;

  /// Already capped at three and filtered to executable actions by the mapper.
  final List<NotificationAction> actions;

  /// The event's own payload — `entity_type`, `entity_id`, and whatever else
  /// the event carries.
  ///
  /// **Every value is a String**, including numbers: the FCM `data` block is
  /// string-only (`"stop_count": "12"`) and the inbox mirrors that shape so one
  /// notification does not parse differently depending on which path delivered
  /// it. Callers parse what they need.
  final Map<String, String> data;

  final NotificationState state;

  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? actionedAt;

  /// True when this item still counts as work the rep owes somebody.
  ///
  /// This — not "unread" — is what the app-icon badge counts (§5.4). A badge
  /// that counts unread mail says "you have mail"; one that counts outstanding
  /// actions says "you have work", and only the second earns an interruption.
  /// Note a **read** assignment is still outstanding: reading is not acting.
  bool get isOutstandingAction => requiresAck && !state.isClosed;

  /// True when the rep may swipe this away. §5.4: an item awaiting
  /// acknowledgement is not dismissable, and the server answers 409 if asked.
  /// Enforcing it here keeps the swipe gesture and the server in agreement.
  bool get isDismissible => !requiresAck && state.isCurrent;

  bool get isUnread => state == NotificationState.unread;

  /// The entity this notification is about, when it names one.
  String? get entityType => data['entity_type'];
  String? get entityId => data['entity_id'];

  /// Local optimistic transition to [NotificationState.read].
  ///
  /// The first read timestamp wins, matching the server: `PATCH /read` is
  /// idempotent because that timestamp is what the time-to-open metric
  /// measures, so replaying it from an offline queue must not move it.
  NotificationMessage markedRead(DateTime at) {
    if (state != NotificationState.unread) return this;
    return copyWith(state: NotificationState.read, readAt: readAt ?? at);
  }

  /// Local optimistic transition to [NotificationState.actioned].
  ///
  /// Terminal states are left alone: an item already `resolved_elsewhere` must
  /// not be rewritten to look like this rep closed it.
  NotificationMessage markedActioned(DateTime at) {
    if (state.isClosed) return this;
    return copyWith(
      state: NotificationState.actioned,
      readAt: readAt ?? at,
      actionedAt: actionedAt ?? at,
    );
  }

  NotificationMessage markedDismissed(DateTime at) {
    if (state.isClosed) return this;
    return copyWith(state: NotificationState.dismissed, readAt: readAt ?? at);
  }

  NotificationMessage copyWith({
    NotificationState? state,
    DateTime? readAt,
    DateTime? actionedAt,
    DateTime? deliveredAt,
    int? badge,
  }) {
    return NotificationMessage(
      id: id,
      eventCode: eventCode,
      category: category,
      priority: priority,
      title: title,
      body: body,
      imageUrl: imageUrl,
      deepLink: deepLink,
      requiresAck: requiresAck,
      expiresAt: expiresAt,
      groupKey: groupKey,
      badge: badge ?? this.badge,
      actions: actions,
      data: data,
      state: state ?? this.state,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      actionedAt: actionedAt ?? this.actionedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        eventCode,
        category,
        priority,
        title,
        body,
        imageUrl,
        deepLink,
        requiresAck,
        expiresAt,
        groupKey,
        badge,
        actions,
        data,
        state,
        createdAt,
        deliveredAt,
        readAt,
        actionedAt,
      ];
}
