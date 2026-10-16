/// A push as this app sees it, with no Firebase types attached.
///
/// `RemoteMessage` stops at the platform boundary. Everything above
/// `PushMessagingService` — the notification repository, the router, the
/// cubits — takes this instead, so the messaging transport can be swapped or
/// no-op'd per platform (ADR-010: web has no FCM registration in this build)
/// without a single import changing upstream.
class PushMessage {
  const PushMessage({
    required this.data,
    this.title,
    this.body,
  });

  /// The FCM `data` block.
  ///
  /// **Every value is a String.** `"stop_count": "12"`, not `12` — FCM has no
  /// other option, and §9.1 flags it because a client that reads these as
  /// numbers throws on the first push carrying one. Parse at the point of use.
  final Map<String, String> data;

  /// From the `notification` block, present when the backend asked the OS to
  /// render an alert. Absent for a data-only push, which is a background sync
  /// trigger with no user-visible alert (§10).
  final String? title;
  final String? body;

  /// True for a data-only push: sync, do not alert.
  bool get isSilent =>
      (title == null || title!.isEmpty) && (body == null || body!.isEmpty);

  /// `notification_id` — the inbox row this push is about, and the upsert key.
  String? get notificationId => data['notification_id'];

  /// The canonical dotted event code (`ROUTE.ASSIGNED`).
  ///
  /// §9.1 ships two naming conventions on purpose: the spec fields
  /// (`event_code`, `entity_type`, `entity_id`, `deep_link`) alongside a mobile
  /// shorthand (`type`, `referenceType`, `referenceId`, `action`), where `type`
  /// is `event_code` with dots flattened to underscores. §18 records that the
  /// duplication is unresolved pending sign-off.
  ///
  /// Rather than pick one and break when the other is the only one present,
  /// this prefers the canonical field and reconstructs it from the shorthand
  /// otherwise. Underscores cannot be un-flattened unambiguously in general, but
  /// the event catalogue uses a single dot, so the first underscore is the
  /// separator.
  String? get eventCode {
    final canonical = data['event_code'];
    if (canonical != null && canonical.isNotEmpty) return canonical;

    final shorthand = data['type'];
    if (shorthand == null || shorthand.isEmpty) return null;
    final split = shorthand.indexOf('_');
    if (split <= 0) return shorthand;
    return '${shorthand.substring(0, split)}.${shorthand.substring(split + 1)}';
  }

  String? get categoryCode => data['category'];
  String? get priorityCode => data['priority'];

  /// The `app://…` URI to open. §11: **the backend builds these** — never
  /// assemble one locally from `entity_type` and `entity_id`, because three
  /// clients deriving the same URI is three chances for one of them to get it
  /// subtly wrong, and the failure (a notification that opens the wrong screen)
  /// is invisible until a rep reports it.
  ///
  /// `action` is the shorthand alias for the same value.
  String? get deepLink {
    final canonical = data['deep_link'];
    if (canonical != null && canonical.isNotEmpty) return canonical;
    final alias = data['action'];
    return (alias != null && alias.isNotEmpty) ? alias : null;
  }

  String? get entityType => data['entity_type'] ?? data['referenceType'];
  String? get entityId => data['entity_id'] ?? data['referenceId'];

  /// The backend's authoritative outstanding-action count, when it rode along.
  /// A snapshot for the app-icon badge before `unread-count` can be called;
  /// §7 still requires reconciling against the server on the next foreground.
  int? get badge => int.tryParse(data['notification_count'] ?? '');

  /// True when the push carries enough to be worth acting on at all.
  ///
  /// A push with no notification id cannot be reconciled against the inbox, so
  /// the only safe response is a plain catch-up. Guarding here keeps that
  /// decision in one place rather than in every handler.
  bool get hasInboxReference =>
      notificationId != null && notificationId!.isNotEmpty;

  @override
  String toString() =>
      // No title, no body, no data values: a push body can name a depot, and
      // `docs/skills/security.md` §10 forbids depot information in logs. Event code
      // and category are safe and are what a diagnosis actually needs.
      'PushMessage(event: $eventCode, category: $categoryCode, '
      'silent: $isSilent)';
}
