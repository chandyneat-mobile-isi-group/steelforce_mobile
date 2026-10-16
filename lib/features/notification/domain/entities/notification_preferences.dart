import 'package:equatable/equatable.dart';

/// One row of the settings screen (`docs/feature/notification/README.md` §13).
///
/// [category] is the raw wire code rather than a [NotificationCategory], and
/// that is deliberate: §13 requires the screen to render whatever the server
/// sends, including a category this build has never heard of. Mapping it through
/// an enum first would collapse every unknown code onto one row and hide the
/// rest.
class NotificationCategoryPreference extends Equatable {
  const NotificationCategoryPreference({
    required this.category,
    required this.displayName,
    required this.isEnabled,
    required this.pushEnabled,
    required this.isLocked,
  });

  /// `ASSIGNMENT`, `KPI`, …
  final String category;

  /// Server-localised label. Render as-is; there is no local string for a
  /// category the app does not know about.
  final String displayName;

  /// Whether the category reaches the rep at all.
  final bool isEnabled;

  /// Whether it may be *pushed*. `pushEnabled: false` with `isEnabled: true` is
  /// a normal, supported combination meaning "inbox only".
  final bool pushEnabled;

  /// The rep may not mute this one.
  ///
  /// Render the toggle **disabled with an explanation, not hidden** — a rep
  /// should be able to see what they are receiving even when they cannot stop
  /// it. Muting one anyway answers `422 Notification.CategoryNotMutable`
  /// rather than silently ignoring the change, so a toggle never snaps back
  /// with no reason given.
  final bool isLocked;

  NotificationCategoryPreference copyWith({
    bool? isEnabled,
    bool? pushEnabled,
  }) =>
      NotificationCategoryPreference(
        category: category,
        displayName: displayName,
        isEnabled: isEnabled ?? this.isEnabled,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        isLocked: isLocked,
      );

  @override
  List<Object?> get props =>
      [category, displayName, isEnabled, pushEnabled, isLocked];
}

/// The rep's notification settings, stored server-side and therefore following
/// them across devices (§13).
///
/// ## Quiet hours defer, they never drop
///
/// A P2 raised at 22:00 is delivered when the window ends; only P4 is withheld
/// entirely, and P1 ignores the window completely. The client renders this
/// window and sends it back — it must not apply it, or a deferred notification
/// is suppressed twice and never seen.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.quietHoursStart,
    this.quietHoursEnd,
    this.quietDays = const [],
    this.digestTime,
    this.language,
    this.categories = const [],
  });

  /// The response a rep who has never opened this screen gets: no quiet window
  /// and no category overrides. §13 is explicit that **absence of a record
  /// means "everything on", not "nothing on"** — so this default must never be
  /// interpreted as "all categories disabled".
  static const NotificationPreferences unset = NotificationPreferences();

  /// `20:00:00`. Sent and received as a wall-clock time-of-day string, paired
  /// with the IANA zone registered for the device — quiet hours are a wall-clock
  /// fact, not an instant.
  final String? quietHoursStart;
  final String? quietHoursEnd;

  /// Day names (`Saturday`) the quiet window applies to.
  ///
  /// **An empty list means every day**, not "no days". Reading it the other way
  /// renders a rep with default settings as having no quiet hours at all.
  final List<String> quietDays;

  final String? digestTime;

  /// BCP 47. Decides which language future notifications are rendered in
  /// server-side.
  final String? language;

  final List<NotificationCategoryPreference> categories;

  /// True when a quiet window is configured at all.
  bool get hasQuietHours => quietHoursStart != null && quietHoursEnd != null;

  /// True when the window wraps midnight (`20:00` → `07:00`), which is the
  /// normal case and is handled server-side. Surfaced only so the UI can label
  /// it "until 07:00 the next day" instead of rendering an apparently backwards
  /// range.
  bool get quietHoursWrapMidnight {
    final start = quietHoursStart;
    final end = quietHoursEnd;
    if (start == null || end == null) return false;
    return start.compareTo(end) > 0;
  }

  /// The window applies every day — see [quietDays].
  bool get quietEveryDay => quietDays.isEmpty;

  NotificationCategoryPreference? categoryPreference(String code) {
    for (final preference in categories) {
      if (preference.category == code) return preference;
    }
    return null;
  }

  NotificationPreferences copyWith({
    String? quietHoursStart,
    String? quietHoursEnd,
    bool clearQuietHours = false,
    List<String>? quietDays,
    String? digestTime,
    String? language,
    List<NotificationCategoryPreference>? categories,
  }) {
    return NotificationPreferences(
      // Start and end must move together: §13 answers
      // `400 Notification.QuietHoursIncomplete` for one without the other, so
      // clearing is an explicit flag rather than "pass null", which `copyWith`
      // cannot distinguish from "leave alone".
      quietHoursStart:
          clearQuietHours ? null : (quietHoursStart ?? this.quietHoursStart),
      quietHoursEnd:
          clearQuietHours ? null : (quietHoursEnd ?? this.quietHoursEnd),
      quietDays: quietDays ?? this.quietDays,
      digestTime: digestTime ?? this.digestTime,
      language: language ?? this.language,
      categories: categories ?? this.categories,
    );
  }

  /// [categories] with the entry for [code] replaced.
  ///
  /// A locked category is returned unchanged rather than optimistically
  /// flipped: the server would refuse it, and a toggle that moves and then
  /// snaps back reads as a bug even when the refusal is correct.
  NotificationPreferences withCategory(
    String code, {
    bool? isEnabled,
    bool? pushEnabled,
  }) {
    return copyWith(
      categories: [
        for (final preference in categories)
          if (preference.category != code || preference.isLocked)
            preference
          else
            preference.copyWith(isEnabled: isEnabled, pushEnabled: pushEnabled),
      ],
    );
  }

  @override
  List<Object?> get props => [
        quietHoursStart,
        quietHoursEnd,
        quietDays,
        digestTime,
        language,
        categories
      ];
}
