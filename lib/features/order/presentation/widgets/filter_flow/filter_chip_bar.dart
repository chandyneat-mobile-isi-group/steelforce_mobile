import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_flow_transition.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The breadcrumb the rep steers by: `Palm › Palm 70 › 0.30 mm › 3.90 m`.
///
/// Sticky, horizontally scrollable, and every chip removable. Removing one
/// doesn't just delete that answer — the bloc drops everything that depended on
/// it, so the trail can never show a thickness that the current family never
/// came in. This widget only reports the tap; the invalidation rule lives in
/// [FilterSelection] where it belongs.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.categoryLabel,
    required this.selection,
    required this.onClearStep,
    required this.onClearCategory,
    this.trailing,
  });

  final String categoryLabel;
  final FilterSelection selection;

  /// Removes one answer and, upstream, everything below it.
  final ValueChanged<String> onClearStep;

  /// Clears the whole flow back to the category list.
  final VoidCallback onClearCategory;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SummaryChip(
                    label: categoryLabel,
                    isRoot: true,
                    onClear: onClearCategory,
                  ),
                  for (final entry in selection.entries) ...[
                    _Separator(color: colors.iconMuted),
                    _SummaryChip(
                      label: entry.option.label,
                      tooltip: entry.stepLabel,
                      onClear: () => onClearStep(entry.stepKey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: context.rw(8)),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.chevron_right_rounded,
            size: context.rr(16), color: color),
      );
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.onClear,
    this.tooltip,
    this.isRoot = false,
  });

  final String label;
  final VoidCallback onClear;
  final String? tooltip;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final chip = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: FilterFlowTransition.duration,
      curve: FilterFlowTransition.curve,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: isRoot
              ? scheme.primary.withValues(alpha: 0.12)
              : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isRoot ? scheme.primary.withValues(alpha: 0.35) : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isRoot ? scheme.primary : colors.textPrimary,
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: context.rw(2)),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(context.rr(3)),
                child: Icon(
                  Icons.close_rounded,
                  size: context.rr(13),
                  color: isRoot ? scheme.primary : colors.iconMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}
