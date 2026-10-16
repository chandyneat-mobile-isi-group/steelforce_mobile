import 'package:flutter/widgets.dart';

/// Tree-scoped registry that lets the coach *observe* where its anchor widgets
/// are, without any shared [GlobalKey].
///
/// ## Why this exists (the crash it fixes)
///
/// The previous design cached one **process-global** `GlobalKey` per anchor id
/// (`CoachKeys.keyFor`). A `GlobalKey` may be attached to at most one place in
/// the tree at a time. During login the app calls
/// `pushNamedAndRemoveUntil(main)`: the old `MainShell` (rebuilt to the
/// authenticated dashboard the instant the session changes) and the newly
/// pushed `MainShell` both mount the dashboard for the transition frame — so the
/// same static key was attached twice and Flutter threw *"Duplicate GlobalKeys
/// detected"*, corrupting the render tree (the `RenderPadding mutated during
/// layout` follow-on).
///
/// Here each anchor instead publishes its **own** `BuildContext` under an id.
/// Two dashboards each own a separate registry (one per `MainShell`), and even
/// within one registry a transient duplicate id simply overwrites the entry —
/// there is no shared key to collide. The coach reads the current context's
/// render box to position the spotlight.
class CoachAnchorRegistry {
  final Map<String, BuildContext> _anchors = {};

  /// Publishes [context] as the live anchor for [id] (last mount wins).
  void register(String id, BuildContext context) => _anchors[id] = context;

  /// Withdraws [context] — but only if it is still the registered one.
  ///
  /// This guard is what makes a navigation transition safe: when an outgoing
  /// anchor and its incoming replacement briefly coexist, the outgoing one's
  /// `dispose` must not evict the incoming (already-registered) context.
  void unregister(String id, BuildContext context) {
    if (identical(_anchors[id], context)) _anchors.remove(id);
  }

  /// The live [BuildContext] for [id], or null when the anchor is absent or
  /// unmounted (e.g. its tab isn't built). Callers use it for
  /// `Scrollable.ensureVisible`.
  BuildContext? contextFor(String id) {
    final ctx = _anchors[id];
    if (ctx == null || !ctx.mounted) return null;
    return ctx;
  }

  /// Current global bounds of [id]'s widget, or null when it isn't laid out.
  /// The coach falls back to a centered bubble on null, so a missing target
  /// degrades gracefully instead of crashing.
  Rect? rectFor(String id) {
    final box = contextFor(id)?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Provides a [CoachAnchorRegistry] to the subtree so anchors can register and
/// the coach can read positions. Wrap `MainShell` in one; the registry instance
/// is owned by the shell's `State`, so each shell has its own.
class CoachAnchorScope extends InheritedWidget {
  const CoachAnchorScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final CoachAnchorRegistry registry;

  static CoachAnchorRegistry? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<CoachAnchorScope>()?.registry;
  }

  static CoachAnchorRegistry of(BuildContext context) {
    final registry = maybeOf(context);
    assert(registry != null,
        'CoachAnchorScope.of() called with no CoachAnchorScope ancestor.');
    return registry!;
  }

  // The registry object is stable for the shell's lifetime, so a rebuild of the
  // scope never needs to notify dependents — anchors read it once and hold it.
  @override
  bool updateShouldNotify(CoachAnchorScope oldWidget) =>
      !identical(registry, oldWidget.registry);
}
