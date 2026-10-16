import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One selectable filter, with the number of promotions behind it.
@immutable
class PromoFilterOption<T> {
  const PromoFilterOption({
    required this.value,
    required this.label,
    required this.count,
    this.icon,
  });

  /// `null` is the conventional "all" option.
  final T? value;
  final String label;
  final int count;
  final IconData? icon;
}

/// The horizontal filter rail above a promotion list.
///
/// Two things it fixes. Options with **no promotions behind them are disabled**
/// rather than tappable — the previous bar offered "OFF-INVOICE (0)", and
/// tapping it took the rep to an empty screen they then had to navigate back
/// out of, which is a dead end presented as a feature. And the labels are no
/// longer SHOUTED IN CAPS, which cost width on a 390pt phone (forcing a scroll
/// the rep could not see was possible) and reads as urgent when nothing is.
class PromoFilterBar<T> extends StatelessWidget {
  const PromoFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<PromoFilterOption<T>> options;
  final T? selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      child: Row(
        children: [
          for (final option in options) ...[
            if (option != options.first) SizedBox(width: context.rw(8)),
            _Chip<T>(
              option: option,
              isSelected: option.value == selected,
              // An option with nothing behind it stays visible — its zero is
              // information, and hiding it would make the bar's contents shift
              // as data loads (FS-UX-2) — but it cannot be entered.
              enabled: option.count > 0,
              onTap: () => onChanged(option.value),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip<T> extends StatelessWidget {
  const _Chip({
    required this.option,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final PromoFilterOption<T> option;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final Color fg;
    final Color bg;
    final Color borderColor;
    if (!enabled) {
      fg = colors.textDisabled;
      bg = colors.surfaceSoft;
      borderColor = colors.border;
    } else if (isSelected) {
      fg = scheme.onPrimary;
      bg = scheme.primary;
      borderColor = scheme.primary;
    } else {
      fg = colors.textPrimary;
      bg = colors.card;
      borderColor = colors.border;
    }

    return Semantics(
      button: enabled,
      selected: isSelected,
      enabled: enabled,
      label: '${option.label} (${option.count})',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(context.rr(12)),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          // 44pt tall before text scaling, so the row clears the touch-target
          // minimum without relying on the label's own height (FS-UX-3).
          constraints: BoxConstraints(minHeight: context.rh(44)),
          padding: EdgeInsets.symmetric(horizontal: context.rw(14)),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(context.rr(12)),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: context.rr(14), color: fg),
                SizedBox(width: context.rw(6)),
              ],
              Text(
                option.label,
                style: TextStyle(
                  color: fg,
                  fontSize: context.rsp(12.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: context.rw(6)),
              // The count as its own pill rather than "(2)" inside the label:
              // it is a different kind of fact from the name, and separating
              // them is what lets the name stay sentence case and readable.
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rw(6),
                  vertical: context.rh(1),
                ),
                decoration: BoxDecoration(
                  color:
                      fg.withValues(alpha: isSelected && enabled ? 0.22 : 0.10),
                  borderRadius: BorderRadius.circular(context.rr(6)),
                ),
                child: Text(
                  '${option.count}',
                  style: TextStyle(
                    color: fg,
                    fontSize: context.rsp(11),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
