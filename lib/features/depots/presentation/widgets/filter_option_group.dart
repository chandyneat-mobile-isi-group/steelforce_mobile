import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// One collapsible filter group: a tappable summary row that always shows the
/// current selection, expanding to reveal its options.
///
/// Motion is all implicit — `AnimatedSize` for the expand, `AnimatedRotation`
/// for the chevron, `AnimatedContainer` for the selected-state colours. No
/// `AnimationController` is created here, so a rebuild cannot restart or
/// stutter an in-flight animation, and there is nothing to dispose.
class FilterOptionGroup extends StatelessWidget {
  const FilterOptionGroup({
    super.key,
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.hasSelection = false,
  });

  final IconData icon;
  final String label;

  /// The current selection rendered in the collapsed row (e.g. "Wholesale"),
  /// or a neutral placeholder such as "All".
  final String valueLabel;

  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: AppCurves.standard,
      decoration: BoxDecoration(
        color: expanded ? colors.surfaceSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSelection
              ? scheme.primary.withValues(alpha: 0.45)
              : colors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Summary(
            icon: icon,
            label: label,
            valueLabel: valueLabel,
            expanded: expanded,
            hasSelection: hasSelection,
            onToggle: onToggle,
          ),
          // AnimatedSize animates the height change; the child is dropped
          // entirely when collapsed so its options cost nothing to lay out.
          AnimatedSize(
            duration: AppDurations.medium,
            curve: AppCurves.emphasized,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.expanded,
    required this.hasSelection,
    required this.onToggle,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final bool expanded;
  final bool hasSelection;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppDurations.medium,
              curve: AppCurves.standard,
              padding: EdgeInsets.all(context.rr(7)),
              decoration: BoxDecoration(
                color: hasSelection
                    ? scheme.primary.withValues(alpha: 0.14)
                    : colors.surfaceStrong,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: context.rr(17),
                color: hasSelection ? scheme.primary : colors.iconMuted,
              ),
            ),
            SizedBox(width: context.rw(12)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11.5),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: context.rh(2)),
                  // Cross-fades the summary text when the selection changes,
                  // instead of the label snapping to a new value.
                  AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: Text(
                      valueLabel,
                      key: ValueKey<String>(valueLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            hasSelection ? scheme.primary : colors.textPrimary,
                        fontSize: context.rsp(13.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.rw(8)),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: AppDurations.medium,
              curve: AppCurves.emphasized,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.iconMuted,
                size: context.rr(22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A selectable pill. Scales down briefly on press and grows a check icon when
/// selected, both via implicit animations.
class FilterChoiceChip extends StatelessWidget {
  const FilterChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return AnimatedScale(
      scale: selected ? 1.0 : 0.98,
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: AppDurations.medium,
            curve: AppCurves.standard,
            padding: EdgeInsets.only(
              left: selected ? 10 : 14,
              right: 14,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.14)
                  : colors.surfaceSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? scheme.primary : colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Width animates 0 → 18 so the pill grows smoothly rather than
                // jumping when the check appears.
                AnimatedSize(
                  duration: AppDurations.fast,
                  curve: AppCurves.standard,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.check_rounded,
                            size: context.rr(14),
                            color: scheme.primary,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? scheme.primary : colors.textPrimary,
                    fontSize: context.rsp(12.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
