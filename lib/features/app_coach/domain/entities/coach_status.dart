/// Lifecycle of the App Coach session.
enum CoachStatus {
  /// Not showing — either never started or already completed/skipped.
  idle,

  /// A step is on screen and (for action steps) waiting for the user action.
  running,

  /// User dismissed the overlay; the floating assistant button offers resume.
  paused,

  /// Tutorial finished. Persisted so it never auto-starts again.
  completed,
}
