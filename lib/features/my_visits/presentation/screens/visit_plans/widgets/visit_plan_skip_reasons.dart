import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The only reasons a rep can give — no free text. Sent in English whatever
/// the UI language so the server's records read the same; each chip shows its
/// translation.
const _reasons = {
  'Shop closed': 'my_visits.route_info.reason_shop_closed',
  'Depot not available': 'my_visits.skip_visit.reason_depot_unavailable',
  'No stock needed': 'my_visits.skip_visit.reason_no_stock_needed',
  'Access denied': 'my_visits.skip_visit.reason_access_denied',
};

/// Skip reasons as chips, red when picked — as on the stop dashboard.
class VisitPlanSkipReasons extends StatelessWidget {
  const VisitPlanSkipReasons({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;

  /// Null while sending: the chips are inert.
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final error = Theme.of(context).colorScheme.error;
    final pick = onSelected;
    return Wrap(
      spacing: context.rw(8),
      runSpacing: context.rh(8),
      children: [
        for (final MapEntry(:key, :value) in _reasons.entries)
          ChoiceChip(
            label: Text(value.tr),
            selected: selected == key,
            onSelected: pick == null ? null : (_) => pick(key),
            selectedColor: error.withValues(alpha: 0.14),
            labelStyle: TextStyle(
              color: selected == key ? error : colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: context.rsp(12),
            ),
            backgroundColor: colors.surfaceSoft,
            side: BorderSide(color: selected == key ? error : colors.border),
          ),
      ],
    );
  }
}
