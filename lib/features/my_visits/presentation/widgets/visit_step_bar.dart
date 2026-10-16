import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// The steps of one depot visit, in the order the rep works them.
enum VisitStep { chooseStop, details, checkIn, inventory, checkOut }

/// "Where am I in this visit": the five visit steps as a compact bar for an
/// app bar's `bottom`. Steps before [current] are ticked, [current] is
/// highlighted, the rest are outlined. A null [current] means the visit is
/// finished and every step is ticked.
class VisitStepBar extends StatelessWidget implements PreferredSizeWidget {
  const VisitStepBar({super.key, required this.current});

  final VisitStep? current;

  /// The step a stop in [status] is waiting on.
  static VisitStep? forStatus(VisitStatus status) => switch (status) {
        VisitStatus.checkedIn => VisitStep.inventory,
        VisitStatus.checkedOut => null,
        _ => VisitStep.details,
      };

  /// Fixed so the app bar can lay out before the labels do. Labels are kept
  /// to one line (scaled down if needed) so a long Khmer word or a large font
  /// setting cannot push the bar past it.
  @override
  Size get preferredSize => const Size.fromHeight(60);

  int get _currentIndex => current?.index ?? VisitStep.values.length;

  @override
  Widget build(BuildContext context) {
    final steps = VisitStep.values;
    final active = current;
    final semantics = active == null
        ? 'my_visits.steps.all_done'.tr
        : 'my_visits.steps.semantics'.trParams({
            'index': active.index + 1,
            'total': steps.length,
            'name': _labelKey(active).tr,
          });

    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: SizedBox(
        height: preferredSize.height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rw(8)),
          child: Row(
            children: [
              for (final step in steps)
                Expanded(
                  child: _StepNode(
                    step: step,
                    done: step.index < _currentIndex,
                    current: step == active,
                    first: step.index == 0,
                    last: step.index == steps.length - 1,
                    lineBeforeDone: step.index <= _currentIndex,
                    lineAfterDone: step.index < _currentIndex,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _labelKey(VisitStep step) => switch (step) {
        VisitStep.chooseStop => 'my_visits.steps.stop',
        VisitStep.details => 'my_visits.steps.details',
        VisitStep.checkIn => 'my_visits.steps.check_in',
        VisitStep.inventory => 'my_visits.steps.inventory',
        VisitStep.checkOut => 'my_visits.steps.check_out',
      };
}

class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: reduceMotion ? Duration.zero : AppDurations.page,
      curve: AppCurves.bounce,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.step,
    required this.done,
    required this.current,
    required this.first,
    required this.last,
    required this.lineBeforeDone,
    required this.lineAfterDone,
  });

  final VisitStep step;
  final bool done;
  final bool current;
  final bool first;
  final bool last;
  final bool lineBeforeDone;
  final bool lineAfterDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final size = context.rr(24);
    final reached = done || current;

    Widget line(bool visible, bool filled) => Expanded(
          child: Container(
            height: 2,
            color: !visible
                ? Colors.transparent
                : filled
                    ? scheme.primary
                    : colors.border,
          ),
        );

    final Widget dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? colors.success
            : current
                ? scheme.primary
                : colors.card,
        border: reached ? null : Border.all(color: colors.border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: done
          ? Icon(Icons.check_rounded,
              size: context.rr(15), color: scheme.onPrimary)
          : Text(
              '${step.index + 1}',
              style: TextStyle(
                fontSize: context.rsp(11),
                fontWeight: FontWeight.w800,
                color: current ? scheme.onPrimary : colors.textSecondary,
              ),
            ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            line(!first, lineBeforeDone),
            // The current step pops in, drawing the eye to where the rep is.
            current ? _PopIn(child: dot) : dot,
            line(!last, lineAfterDone),
          ],
        ),
        SizedBox(height: context.rh(4)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            VisitStepBar._labelKey(step).tr,
            maxLines: 1,
            style: TextStyle(
              fontSize: context.rsp(10.5),
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
              color: current
                  ? scheme.primary
                  : reached
                      ? colors.textPrimary
                      : colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
