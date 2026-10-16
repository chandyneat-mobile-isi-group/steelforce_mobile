import 'dart:convert';

import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/features/notification/data/models/notification_api_mapper.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/domain/entities/queued_notification_action.dart';

/// Drift rows ⇄ notification entities.
///
/// Kept apart from `NotificationApiMapper` because the two translate between
/// genuinely different representations and share nothing but the entity in the
/// middle: the API speaks `snake_case` JSON with nested objects, the database
/// speaks flat columns with two JSON blobs. Folding them together is how a
/// change to one silently alters the other.
///
/// ## Codes, not enum indices
///
/// Enums round-trip through their wire **code** (`ASSIGNMENT`, `P2`,
/// `resolved_elsewhere`), never `Enum.index`. An index column silently remaps
/// every stored row the day somebody inserts a value into the middle of an
/// enum — the exact delayed, invisible failure `core/utils/enum_parse.dart` was
/// written to describe.
extension NotificationRowMapper on NotificationRow {
  /// Row → entity.
  ///
  /// Every field parses tolerantly. A row written by a newer build carrying a
  /// category or state this one does not know must still render: the alternative
  /// is a notification the rep cannot see, and §5.1 keeps everything precisely
  /// so that half-remembered messages stay findable.
  NotificationMessage toEntity() => NotificationMessage(
        id: id,
        eventCode: eventCode,
        category: NotificationCategory.fromCode(category),
        priority: NotificationPriority.fromCode(priority),
        title: title,
        body: body,
        imageUrl: imageUrl,
        deepLink: deepLink,
        requiresAck: requiresAck,
        expiresAt: expiresAt,
        groupKey: groupKey,
        badge: badge,
        actions: NotificationApiMapper.actionsFromJson(
          _decodeJson(actionsJson),
        ),
        data: NotificationApiMapper.dataFromJson(_decodeJson(dataJson)),
        state: NotificationState.fromCode(state),
        // Drift returns the stored instant in local time; every comparison and
        // every cursor in this feature is in UTC, so it is normalised on the way
        // out rather than at each call site.
        createdAt: createdAt.toUtc(),
        deliveredAt: deliveredAt?.toUtc(),
        readAt: readAt?.toUtc(),
        actionedAt: actionedAt?.toUtc(),
      );
}

extension NotificationMessageMapper on NotificationMessage {
  /// Entity → row.
  ///
  /// [partial] marks a row assembled from an FCM payload rather than the inbox
  /// endpoint, so the DAO knows not to let it overwrite a complete record — the
  /// push carries no actions and no full body (§9.2).
  NotificationRow toRow({bool partial = false}) => NotificationRow(
        id: id,
        eventCode: eventCode,
        category: category.code,
        priority: priority.code,
        title: title,
        body: body,
        imageUrl: imageUrl,
        deepLink: deepLink,
        requiresAck: requiresAck,
        expiresAt: expiresAt,
        groupKey: groupKey,
        badge: badge,
        // Null rather than `"[]"` for an empty list, so "no actions" and "not
        // yet known" stay distinguishable in the database — which is what makes
        // a partial row diagnosable.
        actionsJson: actions.isEmpty ? null : jsonEncode(_encodeActions()),
        dataJson: data.isEmpty ? null : jsonEncode(data),
        state: state.code,
        createdAt: createdAt,
        deliveredAt: deliveredAt,
        readAt: readAt,
        actionedAt: actionedAt,
        partial: partial,
      );

  List<Map<String, Object?>> _encodeActions() => [
        for (final action in actions)
          {
            'id': action.id,
            'label': action.label,
            'type': action.type.code,
            'endpoint': action.endpoint,
            'method': action.method,
            'destructive': action.destructive,
          },
      ];
}

extension NotificationActionQueueRowMapper on NotificationActionQueueRow {
  QueuedNotificationAction toEntity() => QueuedNotificationAction(
        id: id,
        notificationId: notificationId,
        kind: NotificationMutationKind.fromCode(kind),
        actionId: actionId,
        category: category,
        occurredAt: occurredAt.toUtc(),
        attempts: attempts,
      );
}

extension NotificationSyncMetaRowMapper on NotificationSyncMetaRow {
  /// The reconciled badge figures as last written by `GET /unread-count`.
  NotificationCounts toCounts() {
    final byCategory = <NotificationCategory, int>{};
    final decoded = _decodeJson(byCategoryJson);
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        final category = NotificationCategory.fromCode(entry.key.toString());
        final count = (entry.value as num?)?.toInt() ?? 0;
        byCategory[category] = (byCategory[category] ?? 0) + count;
      }
    }
    return NotificationCounts(
      unread: unread,
      actionRequired: actionRequired,
      byCategory: byCategory,
      syncTimestamp: countsAt?.toUtc(),
    );
  }

  /// The stored catch-up cursor — the **server's** clock, never the device's
  /// (§6.1).
  DateTime? get cursor => syncTimestamp?.toUtc();
}

/// Decodes a stored JSON blob, tolerating a null or a corrupt one.
///
/// A malformed blob returns null rather than throwing. These columns are written
/// by this app and should never be malformed, but a notification is not worth
/// losing to a truncated write: without the guard, one bad row takes down the
/// whole inbox query it appears in, since the mapper runs inside the stream.
Object? _decodeJson(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}
