/// Hive keys for non-sensitive local preferences and UI state. Never a token,
/// never PII (`.claude/rules/security.md` §2).
/// Split out of the former catch-all `AppConstants`.
abstract final class PreferenceKeys {
  /// Hive key for the cached notification-preferences document (§13).
  ///
  /// Hive rather than the encrypted database, and deliberately: these are the
  /// rep's own toggles and quiet-hours window — settings, not business records
  /// or PII — and they are regenerable from the server on demand
  /// (`docs/blueprint/system-architecture.md` §3, Layer 2). Caching them needs no schema
  /// migration and the cache is never authoritative.
  static const String kNotificationPreferences = 'isi.notification_preferences';

  /// Hive key for when the combined permission primer was last shown.
  ///
  /// Separate from [kPushExplainerShownAt], which gates the *inbox* card for
  /// push alone. This one gates the onboarding dialog that primes push **and**
  /// location together, and the two surfaces are re-offered on their own
  /// schedules — sharing a key would let a dismissal of one silence the other.
  static const String kPermissionPrimerShownAt = 'isi.permission_primer_at';

  /// Hive key for when the push-permission explainer was last shown.
  ///
  /// §14 caps re-showing it at once every 14 days after a decline. Local UI
  /// state with nothing sensitive in it, so Hive is the right home.
  static const String kPushExplainerShownAt = 'isi.push_explainer_shown_at';
}
