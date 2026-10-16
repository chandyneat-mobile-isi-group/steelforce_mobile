/// The user-selectable theme modes.
///
/// [system] follows the OS light/dark setting. It is fully modelled and
/// persisted now (future-ready), and can be surfaced in the UI whenever the
/// product wants it — no further architecture change required.
enum AppThemeMode {
  light,
  dark,
  system;

  /// The stable string persisted to local storage. Uses [name] so the storage
  /// value never depends on enum ordering.
  String get storageValue => name;

  /// Parses a persisted [value] back into a mode, defaulting to [light] — the
  /// app's default — for null/unknown values (e.g. first launch, or a value
  /// written by a newer app version).
  static AppThemeMode fromStorage(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.light,
    );
  }
}
