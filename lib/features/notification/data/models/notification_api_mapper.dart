import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/notification_action.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// Translates the notification API's wire shapes into domain entities.
///
/// ## Why this file is the only place that knows about `snake_case`
///
/// The notification object is `snake_case` while the rest of the API is
/// `camelCase` — `docs/feature/notification/README.md` §5 explains why: the
/// object is quoted verbatim in the published specification and in the FCM
/// payload, so it keeps the spec's casing rather than the API's. That
/// inconsistency is real and permanent, and confining it to one file is the
/// whole point of having a mapper.
///
/// The **preferences** and **device** payloads are ordinary `camelCase`
/// (§4.2, §13), so this file genuinely handles both conventions. Do not
/// "normalise" one to the other.
///
/// ## Tolerance is deliberate, not defensive padding
///
/// Every parse falls back rather than throwing. A notification is a message
/// somebody is accountable for reading; losing one to an unrecognised category
/// or a missing timestamp is worse than rendering it with a generic icon. The
/// enums each document which way they fail and why.
abstract final class NotificationApiMapper {
  const NotificationApiMapper._();

  // ── Inbox ───────────────────────────────────────────────────────────

  /// One notification from `GET /mobile/notifications`.
  ///
  /// Returns null only when there is no usable id — a row that cannot be keyed
  /// cannot be upserted, deduplicated against a push, or acted on, so storing it
  /// would create a duplicate on every single sync.
  static NotificationMessage? fromJson(DataMap json) {
    final id = _string(json['notification_id']) ?? _string(json['id']);
    if (id == null || id.isEmpty) return null;

    // `created_at` is the sort key for the entire inbox, so a missing one cannot
    // be left null. Falling back through `delivered_at` keeps the row in roughly
    // the right place; the epoch as a last resort sorts it to the bottom, which
    // is honest — the app genuinely does not know when it happened.
    final createdAt = parseUtc(json['created_at']) ??
        parseUtc(json['delivered_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return NotificationMessage(
      id: id,
      eventCode: _string(json['event_code']) ?? '',
      category: NotificationCategory.fromCode(_string(json['category'])),
      priority: NotificationPriority.fromCode(_string(json['priority'])),
      title: _string(json['title']) ?? '',
      body: _string(json['body']) ?? '',
      imageUrl: _string(json['image_url']),
      deepLink: _string(json['deep_link']),
      requiresAck: json['requires_ack'] as bool? ?? false,
      expiresAt: parseUtc(json['expires_at']),
      groupKey: _string(json['group_key']),
      badge: (json['badge'] as num?)?.toInt(),
      actions: actionsFromJson(json['actions']),
      data: dataFromJson(json['data']),
      state: NotificationState.fromCode(_string(json['state'])),
      createdAt: createdAt,
      deliveredAt: parseUtc(json['delivered_at']),
      readAt: parseUtc(json['read_at']),
      actionedAt: parseUtc(json['actioned_at']),
    );
  }

  /// Parses the `actions` array, dropping anything unrunnable and capping at
  /// three (§12).
  static List<NotificationAction> actionsFromJson(Object? raw) {
    if (raw is! List) return const [];
    final parsed = <NotificationAction>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final id = _string(map['id']);
      final label = _string(map['label']);
      final type = NotificationActionType.tryFromCode(_string(map['type']));
      // An action with no id cannot be reported back to `POST /action`, and one
      // whose type this build cannot execute would render a button that silently
      // does nothing. Both are dropped rather than guessed at.
      if (id == null || label == null || type == null) continue;
      parsed.add(NotificationAction(
        id: id,
        label: label,
        type: type,
        endpoint: _string(map['endpoint']),
        method: _string(map['method']),
        destructive: map['destructive'] as bool? ?? false,
      ));
    }
    return NotificationAction.take(parsed);
  }

  /// Parses the `data` object into a **string-only** map.
  ///
  /// §9.1: every FCM `data` value is a string (`"stop_count": "12"`, not `12`).
  /// The inbox response is real JSON and may well send a number for the same
  /// field, so values are stringified here rather than cast — one notification
  /// must not parse differently depending on which path delivered it, and a cast
  /// would throw on the first numeric value.
  static Map<String, String> dataFromJson(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value != null) entry.key.toString(): entry.value.toString(),
    };
  }

  /// Builds a partial notification from an FCM payload.
  ///
  /// The push is a deliberate **subset**: no prices, no credit limits, no
  /// depot phone numbers and no `actions` array (§9.2), because a push
  /// renders on a locked screen in front of whoever is holding the phone. So
  /// what comes out of here is enough to render a row and route a tap, and the
  /// catch-up fills in the rest — which is why the repository marks it partial.
  ///
  /// Returns null without a notification id: a push that cannot be reconciled
  /// against the inbox is only a signal to sync, not a row to store.
  static NotificationMessage? fromPush(
    PushMessage push, {
    required DateTime receivedAt,
  }) {
    final id = push.notificationId;
    if (id == null || id.isEmpty) return null;

    return NotificationMessage(
      id: id,
      eventCode: push.eventCode ?? '',
      category: NotificationCategory.fromCode(push.categoryCode),
      priority: NotificationPriority.fromCode(push.priorityCode),
      title: push.title ?? '',
      body: push.body ?? '',
      deepLink: push.deepLink,
      // The payload carries no `requires_ack`, and guessing `true` would pin a
      // routine update to the top of the Action needed tab and refuse to let the
      // rep dismiss it. False until the catch-up says otherwise.
      requiresAck: false,
      badge: push.badge,
      // No actions: the push does not carry them. `partial` on the row is what
      // stops this reading as "a notification that offers no actions".
      data: push.data,
      state: NotificationState.unread,
      // The device clock, used only for local ordering until the catch-up
      // replaces it with the server's `created_at`. Never sent back as a cursor
      // — §6.1's warning about the device clock is about exactly that.
      createdAt: receivedAt,
      deliveredAt: receivedAt,
    );
  }

  // ── Counts ──────────────────────────────────────────────────────────

  /// `GET /unread-count` → the authoritative badge figures (§7).
  static NotificationCounts countsFromJson(DataMap json) {
    final byCategory = <NotificationCategory, int>{};
    final raw = json['by_category'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final category = NotificationCategory.fromCode(entry.key.toString());
        // Unknown codes are summed onto `unknown` rather than dropped: the total
        // still adds up, and a category this build has not heard of is not a
        // reason to under-report the rep's workload.
        final count = (entry.value as num?)?.toInt() ?? 0;
        byCategory[category] = (byCategory[category] ?? 0) + count;
      }
    }

    return NotificationCounts(
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      actionRequired: (json['action_required'] as num?)?.toInt() ?? 0,
      byCategory: byCategory,
      syncTimestamp: parseUtc(json['sync_timestamp']),
    );
  }

  // ── Devices ─────────────────────────────────────────────────────────

  /// `POST /mobile/devices/register` request body (§4.2). `camelCase`.
  static DataMap registrationToJson(PushRegistration registration) => {
        'deviceId': registration.deviceId,
        'pushToken': registration.pushToken,
        'platform': registration.platform.code,
        // Omitted rather than sent empty: the device registry shows these to
        // support, and a blank row is less useful than an absent field.
        if (registration.deviceName?.isNotEmpty ?? false)
          'deviceName': registration.deviceName,
        if (registration.appVersion?.isNotEmpty ?? false)
          'appVersion': registration.appVersion,
        if (registration.osVersion?.isNotEmpty ?? false)
          'osVersion': registration.osVersion,
        if (registration.locale?.isNotEmpty ?? false)
          'locale': registration.locale,
        if (registration.timeZone?.isNotEmpty ?? false)
          'timeZone': registration.timeZone,
        // Always sent, including when false. §4.2: a declined registration is
        // kept but excluded from the push audience, which makes the delivery log
        // read `NO_DEVICE` instead of a run of failures.
        'pushPermissionGranted': registration.pushPermissionGranted,
        'latitude': registration.latitude,
        'longitude': registration.longitude,
        'locationAccuracyMeters': registration.locationAccuracyMeters,
        'locationCapturedAt':
            registration.locationCapturedAt.toUtc().toIso8601String(),
      };

  /// `POST /mobile/devices/register` response (§4.3).
  static PushRegistrationResult registrationFromJson(DataMap json) =>
      PushRegistrationResult(
        id: _string(json['id']) ?? '',
        deviceId: _string(json['deviceId']) ?? '',
        // Defaults to true because that is what a 2xx from this endpoint means:
        // a registration the backend had deactivated is *revived* by the call.
        // Defaulting to false would report a working registration as dead.
        isActive: json['isActive'] as bool? ?? true,
        pushPermissionGranted: json['pushPermissionGranted'] as bool? ?? false,
        lastSeenAt: parseUtc(json['lastSeenAt']),
      );

  // ── Preferences ─────────────────────────────────────────────────────

  /// `GET /mobile/notifications/preferences` (§13). `camelCase`.
  static NotificationPreferences preferencesFromJson(DataMap json) {
    final categories = <NotificationCategoryPreference>[];
    final raw = json['categories'];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final code = _string(map['category']);
        if (code == null || code.isEmpty) continue;
        categories.add(NotificationCategoryPreference(
          category: code,
          // Falls back to the raw code rather than a translated label: §13
          // requires the screen to render categories the app has never heard
          // of, and the code is at least accurate.
          displayName: _string(map['displayName']) ?? code,
          // Both default to **true**. §13: a rep who has never opened this
          // screen gets everything on, and absence of a record means
          // "everything", not "nothing". Defaulting to false would render a
          // fresh account as having muted its own notifications.
          isEnabled: map['isEnabled'] as bool? ?? true,
          pushEnabled: map['pushEnabled'] as bool? ?? true,
          isLocked: map['isLocked'] as bool? ?? false,
        ));
      }
    }

    return NotificationPreferences(
      quietHoursStart: _string(json['quietHoursStart']),
      quietHoursEnd: _string(json['quietHoursEnd']),
      quietDays: _stringList(json['quietDays']),
      digestTime: _string(json['digestTime']),
      language: _string(json['language']),
      categories: categories,
    );
  }

  /// `PUT /mobile/notifications/preferences` body.
  ///
  /// One contract rule is enforced here rather than left to the caller:
  /// `quietHoursStart` and `quietHoursEnd` go **together or not at all**, since
  /// one without the other answers `400 Notification.QuietHoursIncomplete`. A
  /// half-set window is dropped rather than sent, so a partially-filled form
  /// cannot produce an error the rep has no way to interpret.
  static DataMap preferencesToJson(NotificationPreferences preferences) {
    final hasWindow = preferences.quietHoursStart != null &&
        preferences.quietHoursEnd != null;

    return {
      if (hasWindow) 'quietHoursStart': preferences.quietHoursStart,
      if (hasWindow) 'quietHoursEnd': preferences.quietHoursEnd,
      // Always sent, because an empty list is meaningful: §13 says
      // `quietDays: []` means **every day**, not "no days".
      'quietDays': preferences.quietDays,
      if (preferences.digestTime != null) 'digestTime': preferences.digestTime,
      if (preferences.language != null) 'language': preferences.language,
      'categories': [
        for (final category in preferences.categories)
          // Locked categories are omitted entirely. Sending one back — even
          // unchanged — risks `422 Notification.CategoryNotMutable` on a value
          // the rep never touched, which would fail the whole save.
          if (!category.isLocked)
            {
              'category': category.category,
              'isEnabled': category.isEnabled,
              'pushEnabled': category.pushEnabled,
            },
      ],
    };
  }

  // ── Primitives ──────────────────────────────────────────────────────

  /// A non-empty string, or null.
  ///
  /// Empty-to-null matters here: the API sends `""` for absent optional text in
  /// places, and `deepLink == ''` would be treated as a routable link and open
  /// nothing.
  static String? _string(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString();
    return value.isEmpty ? null : value;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .where((e) => e != null)
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
