/// How loud a notification is allowed to be
/// (`docs/feature/notification/README.md` §5.2).
///
/// The tier is decided by the backend and is *already applied* by the time the
/// row reaches the device — quiet hours have been honoured or bypassed, the
/// push has been sent or withheld. The client reads this only to render and to
/// sort; it must never re-implement the policy, or a P1 route cancellation gets
/// suppressed twice and nobody is woken.
enum NotificationPriority {
  /// Critical. Bypasses quiet hours *and* the rep's own opt-out, pushed at high
  /// priority with an alert tone. A route cancelled at midnight for an 06:00
  /// start has to wake somebody.
  p1('P1'),

  /// High. Deferred to the end of a quiet window, heads-up banner.
  p2('P2'),

  /// Normal. Deferred to the end of a quiet window, silent-capable.
  p3('P3'),

  /// Low. **Never pushed** — inbox only.
  ///
  /// This is the tier that punishes a client whose only render path is the FCM
  /// callback: every digest and every "route completed" confirmation is a P4,
  /// so such a client shows none of them and looks simply empty.
  p4('P4');

  const NotificationPriority(this.code);

  final String code;

  /// True when this tier is never delivered as a push, so the only way it can
  /// reach the rep is the inbox catch-up call (§6.1).
  bool get isInboxOnly => this == p4;

  /// Sort weight, most urgent first. P1 → 0.
  int get rank => index;

  /// Parses a wire code. Falls back to [p3] rather than to the loudest or the
  /// quietest tier: an unrecognised value is a version skew, and both
  /// alternatives are wrong in a way that matters — [p1] would fake an
  /// escalation the backend never authorised, [p4] would hide the item.
  static NotificationPriority fromCode(String? code) {
    if (code == null || code.isEmpty) return p3;
    final normalized = code.toUpperCase();
    for (final value in values) {
      if (value.code == normalized) return value;
    }
    return p3;
  }
}
