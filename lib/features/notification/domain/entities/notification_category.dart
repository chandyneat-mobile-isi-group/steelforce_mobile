/// The ten groupings every notification belongs to
/// (`docs/feature/notification/README.md` §5.3).
///
/// The wire values are the SCREAMING_SNAKE codes the backend sends, kept
/// verbatim as [code] rather than derived from `name`: `ANNOUNCE` and
/// `SECURITY` would round-trip fine, but a future `CREDIT_HOLD` would not, and
/// a mapping that works by accident is one rename away from silently dropping
/// a whole category.
///
/// ## This enum is not the settings screen
///
/// §5.3 and §13 are explicit that the **settings screen must be built from
/// `GET /notifications/preferences`**, not from a list compiled into the app —
/// a category added server-side is invisible until the next release otherwise.
/// This enum exists for the two jobs that genuinely need a compile-time value:
///
///  * mapping a category onto its Android notification channel
///    (`NotificationChannels`), which has to exist before the first push
///    arrives and therefore cannot be fetched;
///  * choosing an icon and an accent colour in the inbox.
///
/// Both of those degrade gracefully through [unknown]. Anything that enumerates
/// categories *for the user* must read the API.
enum NotificationCategory {
  assignment('ASSIGNMENT'),
  quote('QUOTE'),
  order('ORDER'),
  finance('FINANCE'),
  kpi('KPI'),
  approval('APPROVAL'),
  account('ACCOUNT'),
  system('SYSTEM'),
  announce('ANNOUNCE'),
  security('SECURITY'),

  /// A category this build has never heard of.
  ///
  /// Deliberately a real value rather than a null or a thrown error. The
  /// backend's category list grows independently of the app's release cycle,
  /// and a notification the rep cannot see is strictly worse than one rendered
  /// with a generic icon: §5.1 says nothing is ever deleted precisely so a rep
  /// who half-remembers being told something can find it.
  unknown('UNKNOWN');

  const NotificationCategory(this.code);

  /// The wire value, e.g. `ASSIGNMENT`. Send and store this, never [name].
  final String code;

  /// Parses a wire code, falling back to [unknown].
  ///
  /// Case-insensitive because the delivery log and the FCM `data` block have
  /// been observed carrying the same code in different cases, and a rep should
  /// not lose a notification to a capitalisation difference.
  static NotificationCategory fromCode(String? code) {
    if (code == null || code.isEmpty) return unknown;
    final normalized = code.toUpperCase();
    for (final value in values) {
      if (value.code == normalized) return value;
    }
    return unknown;
  }

  /// Every real category, in the order §5.3 lists them — [unknown] excluded,
  /// because it is a parsing outcome and never something to offer or query.
  static List<NotificationCategory> get addressable =>
      values.where((c) => c != unknown).toList(growable: false);
}
