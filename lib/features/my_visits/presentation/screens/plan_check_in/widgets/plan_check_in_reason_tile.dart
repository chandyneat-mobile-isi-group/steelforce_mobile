import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One reason as a full-width choice; the picked one is outlined in the
/// brand colour with a check.
class PlanCheckInReasonTile extends StatelessWidget {
  const PlanCheckInReasonTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final accent = selected ? scheme.primary : colors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.symmetric(
              horizontal: context.rw(14), vertical: context.rh(10)),
          decoration: BoxDecoration(
            color:
                selected ? scheme.primary.withValues(alpha: 0.08) : colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: context.rr(20), color: accent),
              SizedBox(width: context.rw(12)),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(14),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected
                    ? Icon(Icons.check_circle_rounded,
                        key: const ValueKey('on'),
                        size: context.rr(20),
                        color: scheme.primary)
                    : Icon(Icons.radio_button_unchecked_rounded,
                        key: const ValueKey('off'),
                        size: context.rr(20),
                        color: colors.border),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
