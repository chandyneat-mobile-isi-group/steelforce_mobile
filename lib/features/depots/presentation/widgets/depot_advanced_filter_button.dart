import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The Advanced Filters toggle beside the search field: a square of the
/// field's own height and shape, so the field keeps the row. A badge counts
/// the filters set; it reads as pressed while the panel is open.
class DepotAdvancedFilterButton extends StatelessWidget {
  const DepotAdvancedFilterButton({
    super.key,
    required this.open,
    required this.activeCount,
    required this.onTap,
  });

  final bool open;
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final highlighted = open || activeCount > 0;
    final size = context.rh(44);

    return Tooltip(
      message: 'depots.filters.advanced'.tr,
      child: Semantics(
        button: true,
        expanded: open,
        label: 'depots.filters.advanced'.tr,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: open ? scheme.primary : colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: highlighted ? scheme.primary : colors.border),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: context.rr(20),
                  color: open
                      ? scheme.onPrimary
                      : highlighted
                          ? scheme.primary
                          : colors.textSecondary,
                ),
              ),
              if (activeCount > 0)
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: Container(
                    constraints: BoxConstraints(
                        minWidth: context.rr(18), minHeight: context.rr(18)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.card, width: 1.5),
                    ),
                    child: Text(
                      '$activeCount',
                      style: TextStyle(
                        color: scheme.onError,
                        fontSize: context.rsp(10),
                        fontWeight: FontWeight.w800,
                      ),
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
