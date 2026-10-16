/// Where a notification sits in its lifecycle
/// (`docs/feature/notification/README.md` §5.1).
///
/// ```
///                     ┌──────────┐  read     ┌────────┐  acted    ┌────────────┐
///    created ────────▶│  unread  │──────────▶│  read  │──────────▶│  actioned  │
///                     └────┬─────┘           └───┬────┘           └────────────┘
///                          │                     │
///               ┌──────────┼─────────────────────┤
///               ▼          ▼                     ▼
///        ┌───────────┐ ┌─────────┐    ┌────────────────────┐
///        │ dismissed │ │ expired │    │ resolved_elsewhere │
///        └───────────┘ └─────────┘    └────────────────────┘
/// ```
///
/// **Nothing is ever deleted.** Every terminal state stays in the inbox history
/// with an explanatory subtitle, because a rep who half-remembers being told
/// something has to be able to find it. [dismissed], [expired] and
/// [resolvedElsewhere] are history, not absence.
enum NotificationState {
  /// Not opened. Bold, with an unread dot.
  unread('unread'),

  /// Opened. Normal weight.
  read('read'),

  /// The rep did the thing. Normal, with a tick.
  ///
  /// Reached only through `POST /action` — never through `/read`. Wiring
  /// "scrolled past it" to this state breaks the supervisor escalation chain
  /// the whole assignment flow depends on (§8.3).
  actioned('actioned'),

  /// Swiped away. History only.
  dismissed('dismissed'),

  /// Its moment passed unread. History, greyed, "this is no longer current".
  expired('expired'),

  /// Somebody else decided first — another approver, or a reassignment that
  /// happened while this handset was offline. History, greyed, "already
  /// actioned by someone else".
  resolvedElsewhere('resolved_elsewhere');

  const NotificationState(this.code);

  /// The wire value. Snake_case, matching the published spec — do not derive it
  /// from [name], which would emit `resolvedElsewhere`.
  final String code;

  /// True while the item still belongs in the live inbox rather than history.
  bool get isCurrent => this == unread || this == read;

  /// True once no further action is possible, whoever took it.
  bool get isClosed =>
      this == actioned ||
      this == dismissed ||
      this == expired ||
      this == resolvedElsewhere;

  /// True when the item is closed by something *other* than this rep acting on
  /// it, which is what earns the greyed "no longer current" treatment.
  bool get isStale => this == expired || this == resolvedElsewhere;

  /// Parses a wire code, falling back to [unread].
  ///
  /// [unread] is the safe fallback: an unrecognised state leaves the item
  /// visible and actionable. Falling back to a closed state would hide work
  /// the rep is still accountable for.
  static NotificationState fromCode(String? code) {
    if (code == null || code.isEmpty) return unread;
    final normalized = code.toLowerCase();
    for (final value in values) {
      if (value.code == normalized) return value;
    }
    return unread;
  }
}
