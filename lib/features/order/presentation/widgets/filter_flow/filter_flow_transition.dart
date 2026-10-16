import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';

/// The one motion spec every stage of the guided configurator uses.
///
/// Centralised so category → family → specification → products all feel like
/// the same object moving, rather than four screens that each animate slightly
/// differently. Material's standard "shared axis" reading: the outgoing stage
/// fades and slides out, the incoming one fades and slides in from the leading
/// edge, with the container resizing rather than jumping.
///
/// ## Motion tokens, not local constants
///
/// The durations and curves come from [AppDurations] / [AppCurves].
/// `docs/skills/feature-ui-standard.md` §14 makes that a blocking rule, and the
/// reason is visible in this feature: the configurator used a local `260ms`
/// while the rest of the app moved at [AppDurations.medium], so a stage change
/// and the sheet it happened inside were animating at different speeds.
///
/// The shape of the motion is unchanged — this is the same shared-axis
/// transition, re-expressed in the app's vocabulary.
///
/// ## Reduce motion
///
/// Honoured, and it has to be: a shared-axis slide plus a resizing container is
/// precisely the combination a motion-sensitive rep should not be given, and
/// §14 lists it as blocking. With animations disabled the stage swaps
/// instantly — no slide, no fade, no resize — which is a legitimate rendering
/// of the same information rather than a degraded one.
class FilterFlowTransition extends StatelessWidget {
  const FilterFlowTransition({
    super.key,
    required this.stageKey,
    required this.child,
    this.reverse = false,
  });

  /// Changing this is what triggers the transition. Use something that
  /// identifies the *stage*, not the data (e.g. the active step key), so a
  /// loading→loaded refresh doesn't replay the animation.
  final Object stageKey;

  /// True when moving backwards, so the slide direction inverts and the motion
  /// reads as retracing rather than progressing.
  final bool reverse;

  final Widget child;

  /// The stage-change duration.
  ///
  /// [AppDurations.medium] (250ms) rather than the previous local 260ms —
  /// visually identical, and now the same value the rest of the app uses for a
  /// content swap.
  static const Duration duration = AppDurations.medium;

  /// Entrance easing. [AppCurves.standard] is the app's decelerate curve and is
  /// the same `easeOutCubic` this file declared for itself.
  static const Curve curve = AppCurves.standard;

  /// Exit easing. Deliberately *not* [curve]: an outgoing stage should
  /// accelerate away rather than decelerate into nothing, or the two halves of
  /// the cross-fade both linger in the middle and read as a smear.
  static const Curve exitCurve = Curves.easeInCubic;

  @override
  Widget build(BuildContext context) {
    final keyed = KeyedSubtree(key: ValueKey(stageKey), child: child);

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      // Returned bare, not with a zero duration. `AnimatedSize` still lays out
      // and drives a controller at zero duration; omitting it entirely is both
      // cheaper and structurally absent, so it cannot affect intrinsic sizing.
      return keyed;
    }

    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: curve,
        switchOutCurve: exitCurve,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) {
          // Transform and opacity only — never a layout property. Sliding by
          // `left`/`width` would relayout the whole stage every frame.
          final offset = Tween<Offset>(
            begin: Offset(reverse ? -0.06 : 0.06, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: keyed,
      ),
    );
  }
}

/// Staggered entrance for the options inside a stage — each chip/tile arrives
/// a beat after the one before it, which reads as the list assembling instead
/// of appearing.
///
/// The delay is **capped**: at [_step] per item an unbounded stagger would make
/// the fortieth material in a category wait almost a second, so the tail of a
/// long list arrives together rather than eventually.
///
/// Reduce-motion returns the child untouched. A stagger is the one animation a
/// motion-sensitive user cannot look away from, because it is the content
/// itself arriving.
class FilterFlowStaggeredItem extends StatelessWidget {
  const FilterFlowStaggeredItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  /// Per-item offset. Shorter than [AppDurations.stagger] (40ms) on purpose:
  /// that token is tuned for a handful of dashboard cards, and a category can
  /// hold forty chips — at 40ms each the list would assemble over 1.6s.
  static const Duration _step = Duration(milliseconds: 22);

  /// The point after which every remaining item arrives together.
  static const Duration _maxDelay = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }

    final delay = Duration(
      milliseconds: (index * _step.inMilliseconds)
          .clamp(0, _maxDelay.inMilliseconds)
          .toInt(),
    );
    final total = FilterFlowTransition.duration + delay;

    return TweenAnimationBuilder<double>(
      key: ValueKey('stagger-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: total,
      // The delay is expressed as a dead interval at the head of one curve
      // rather than a `Future.delayed` — so there is one controller per item
      // instead of a timer, and rebuilding mid-flight cannot leave a pending
      // callback that fires into a disposed element.
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: FilterFlowTransition.curve,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 8),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
