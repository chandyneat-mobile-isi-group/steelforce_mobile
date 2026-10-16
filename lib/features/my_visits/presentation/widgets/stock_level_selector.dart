import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Semantic color for each [StockLevel], resolved from the active
/// [ColorScheme] only — supports light + dark with no hardcoded colors.
Color stockLevelColor(BuildContext context, StockLevel level) {
  final scheme = Theme.of(context).colorScheme;
  return switch (level) {
    StockLevel.low => scheme.error,
    StockLevel.medium => scheme.tertiary,
    StockLevel.high => scheme.primary,
  };
}

/// Localized label for a [StockLevel] segment.
String stockLevelLabel(StockLevel level) => switch (level) {
      StockLevel.low => 'my_visits.stock_level.low'.tr,
      StockLevel.medium => 'my_visits.stock_level.medium'.tr,
      StockLevel.high => 'my_visits.stock_level.high'.tr,
    };

/// Single-choice Low / Medium / High control (Material 3 [SegmentedButton]).
/// Unset until the rep picks; selection is exclusive and animates via the
/// segmented button's built-in state layer plus the color transition below.
class StockLevelSelector extends StatelessWidget {
  const StockLevelSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final StockLevel? value;
  final ValueChanged<StockLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selectedColor =
        value == null ? null : stockLevelColor(context, value!);

    return SegmentedButton<StockLevel>(
      segments: [
        for (final level in StockLevel.values)
          ButtonSegment(
            value: level,
            label: Text(stockLevelLabel(level), maxLines: 1),
          ),
      ],
      selected: {if (value != null) value!},
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return; // one status must stay selected
        HapticFeedback.selectionClick();
        onChanged(selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        textStyle: WidgetStatePropertyAll(TextStyle(
            fontSize: context.rsp(12.5), fontWeight: FontWeight.w700)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return selectedColor?.withValues(alpha: 0.14);
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return selectedColor;
          return colors.textSecondary;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(
                color: selectedColor ?? colors.border, width: 1.2);
          }
          return BorderSide(color: colors.border);
        }),
      ),
    );
  }
}

/// One product card in a stock-status sweep: image, name, SKU (and optional
/// size), and the Low / Medium / High selector. Presentational — the selected
/// level and its mutation live in the owning cubit/screen state.
class StockLevelRow extends StatelessWidget {
  const StockLevelRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.level,
    required this.onLevelSelected,
    this.imageUrl = '',
    this.size = '',
    this.showMissingHighlight = false,
  });

  final String name;
  final String subtitle;
  final String imageUrl;
  final String size;
  final StockLevel? level;
  final ValueChanged<StockLevel> onLevelSelected;

  /// When true and no [level] is set, the card outlines itself in the error
  /// color so incomplete items are obvious at completion time.
  final bool showMissingHighlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final missing = showMissingHighlight && level == null;
    final borderColor = missing
        ? scheme.error.withValues(alpha: 0.6)
        : level != null
            ? stockLevelColor(context, level!).withValues(alpha: 0.45)
            : colors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProductThumb(imageUrl: imageUrl),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: context.rsp(14),
                            fontWeight: FontWeight.w800)),
                    if (subtitle.isNotEmpty || size.isNotEmpty) ...[
                      SizedBox(height: context.rh(2)),
                      Text(
                        [subtitle, size].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11)),
                      ),
                    ],
                  ],
                ),
              ),
              if (missing) ...[
                SizedBox(width: context.rw(8)),
                Icon(Icons.error_outline_rounded,
                    size: context.rr(18), color: scheme.error),
              ],
            ],
          ),
          SizedBox(height: context.rh(10)),
          SizedBox(
            width: double.infinity,
            child: StockLevelSelector(value: level, onChanged: onLevelSelected),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fallback = Icon(Icons.inventory_2_outlined,
        size: context.rr(20), color: colors.iconMuted);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: context.rh(40),
        color: colors.surfaceSoft,
        alignment: Alignment.center,
        child: imageUrl.isEmpty
            ? fallback
            // Offline-first: a missing/unreachable image degrades to the
            // placeholder icon, never an error surface.
            : Image.network(imageUrl,
                fit: BoxFit.cover,
                width: 40,
                height: context.rh(40),
                errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }
}
