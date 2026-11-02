import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message_text.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';

/// Reads the `/me/notifications` shapes (backend `InboxModels.cs`):
///
/// ```json
/// { "id": "…", "type": "planning.visits-assigned",
///   "title": { "en": "…", "km": "…" }, "body": { "en": "…", "km": "…" },
///   "link": { "targetType": "visit-plans", "targetId": "2026-10-22" },
///   "createdAt": "…", "readAt": null }
/// ```
///
/// `link` is null when there is nothing to open. It is kept twice: raw in
/// `data` (as the push sends it), and as the app's own `app://type/id` form
/// in `deepLink`, which is what `NotificationDeepLink` routes.
abstract final class InboxItemMapper {
  const InboxItemMapper._();

  /// One `InboxItem`; null without an id, which could not be upserted.
  static NotificationMessage? fromJson(DataMap json) {
    final id = _string(json['id']);
    if (id == null || id.isEmpty) return null;

    final type = _string(json['type']) ?? '';
    final title = _text(json['title']);
    final body = _text(json['body']);
    final link = json['link'];
    final targetType = link is Map ? _string(link['targetType']) : null;
    final targetId = link is Map ? _string(link['targetId']) : null;
    final readAt = parseUtc(json['readAt']);

    return NotificationMessage(
      id: id,
      eventCode: type,
      category: categoryForType(type),
      priority: NotificationPriority.fromCode(null),
      title: title.en,
      body: body.en,
      deepLink: NotificationDeepLink.fromTarget(targetType, targetId),
      data: {
        NotificationDataKeys.titleKm: title.km,
        NotificationDataKeys.bodyKm: body.km,
        if (targetType != null && targetId != null) ...{
          NotificationDataKeys.targetType: targetType,
          NotificationDataKeys.targetId: targetId,
        },
      },
      state: readAt == null ? NotificationState.unread : NotificationState.read,
      // The inbox sorts on this; the epoch sorts an undated row last.
      createdAt: parseUtc(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      readAt: readAt,
    );
  }

  /// `InboxPage.items`, skipping any row without an id.
  static List<NotificationMessage> itemsFromJson(Object? raw) => [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map)
              if (fromJson(entry.cast<String, dynamic>()) case final item?)
                item,
      ];

  /// `UnreadCount` → `{ "count": 3 }`.
  static NotificationCounts countsFromJson(DataMap json) =>
      NotificationCounts(unread: (json['count'] as num?)?.toInt() ?? 0);

  /// The API has no category, only a `type` such as `planning.visits-assigned`;
  /// its module picks the icon. Planning is the only module that publishes
  /// today; any other gets the generic icon.
  static NotificationCategory categoryForType(String? type) =>
      switch (type?.split('.').first.toLowerCase()) {
        'planning' => NotificationCategory.assignment,
        _ => NotificationCategory.unknown,
      };

  /// `LocalizedText`; a bare string is taken as both languages.
  static ({String en, String km}) _text(Object? raw) {
    if (raw is Map) {
      final en = _string(raw['en']) ?? '';
      return (en: en, km: _string(raw['km']) ?? en);
    }
    final text = _string(raw) ?? '';
    return (en: text, km: text);
  }

  static String? _string(Object? raw) => raw?.toString();
}
