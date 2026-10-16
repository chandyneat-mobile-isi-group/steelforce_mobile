import 'package:flutter/foundation.dart';

/// Rebuilds the entire `MaterialApp` — Navigator, route stack and every screen
/// under it — from scratch.
///
/// Used by sign-out. Clearing the session is not enough on its own: whatever
/// the rep had open is still mounted, still holds the blocs it was built with,
/// and is still reachable with the Back button. Rather than trying to unwind
/// that stack screen by screen, the app is torn down and rebuilt, which
/// re-resolves the initial route against the now-guest session and leaves no
/// history behind to navigate back into.
///
/// This is the same mechanism the app already uses for a language change (a
/// `ValueKey` on `MaterialApp`), generalised so more than one thing can ask for
/// it. A restart is cheap here because nothing durable lives in widget state —
/// the database and secure storage are untouched by it.
class AppRestartController extends ValueNotifier<int> {
  AppRestartController() : super(0);

  /// Bumping the generation changes `MaterialApp`'s key, which is what forces
  /// the rebuild. Monotonic so two restarts in a row are still two rebuilds.
  void restart() => value = value + 1;
}
