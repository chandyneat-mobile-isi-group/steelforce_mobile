import 'package:flutter/widgets.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_anchor_registry.dart';

/// The catalog of coach anchor ids and the [wrap] helper that attaches an anchor
/// to a widget.
///
/// The domain stays framework-free: `CoachStepCatalog` references only the
/// `const String` ids below, and the presentation layer resolves an id to a
/// live widget position through the [CoachAnchorRegistry] (see
/// `coach_anchor_registry.dart`).
///
/// **No `GlobalKey`s here anymore.** They used to be cached statically, which
/// crashed with "Duplicate GlobalKeys" whenever two shells were mounted at once
/// (the login navigation transition). [wrap] now attaches a lightweight
/// [_CoachAnchor] that publishes its own `BuildContext`, so nothing global is
/// shared between widget instances.
abstract final class CoachKeys {
  // ── Anchor ids (must match CoachStepCatalog.targetKeyId values) ──────────
  static const String monthlyTarget = 'monthly_target';
  static const String myWork = 'my_work';

  // My-work items.
  static const String myVisits = 'mw_my_visits';
  static const String myDepots = 'mw_my_depots';
  static const String orders = 'mw_orders';

  // App-bar items.
  static const String notification = 'ab_notification';
  static const String profile = 'ab_profile';

  /// Wrap an anchor widget so the coach can locate it:
  /// `CoachKeys.wrap(CoachKeys.monthlyTarget, child: MonthlyTargetCard(...))`.
  ///
  /// Requires a [CoachAnchorScope] ancestor (provided by `MainShell`). If none
  /// is present the child is returned unchanged — the coach simply won't find
  /// this anchor, which is a graceful no-op rather than a crash.
  static Widget wrap(String id, {required Widget child}) =>
      _CoachAnchor(id: id, child: child);
}

/// Registers its own [BuildContext] as the live anchor for [id] while mounted.
///
/// Deliberately a `StatefulWidget`: it needs a stable element whose lifecycle
/// (`didChangeDependencies`/`dispose`) maps 1:1 to the anchor being on/off
/// screen, and its `context.findRenderObject()` yields the child's render box —
/// exactly what the previous `GlobalKey` provided, minus the global sharing.
class _CoachAnchor extends StatefulWidget {
  const _CoachAnchor({required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<_CoachAnchor> createState() => _CoachAnchorState();
}

class _CoachAnchorState extends State<_CoachAnchor> {
  CoachAnchorRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope is stable, so this resolves once and never churns. Re-register
    // if this element is ever moved under a different scope.
    final registry = CoachAnchorScope.maybeOf(context);
    if (!identical(registry, _registry)) {
      _registry?.unregister(widget.id, context);
      _registry = registry;
      _registry?.register(widget.id, context);
    }
  }

  @override
  void dispose() {
    _registry?.unregister(widget.id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
