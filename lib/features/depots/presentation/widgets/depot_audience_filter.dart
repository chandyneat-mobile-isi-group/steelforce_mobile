import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';

/// Which list the depots screen is showing.
enum DepotAudience {
  depots('depots.title', DepotListKind.depot),
  nonBpDepots('depots.non_bp.audience', DepotListKind.nonBp),
  awaitingApproval('depots.awaiting.audience', DepotListKind.awaitingApproval);

  const DepotAudience(this.labelKey, this.kind);

  final String labelKey;

  /// The rows this list shows.
  final DepotListKind kind;

  /// Resolved on every read so the segment follows a language change.
  String get label => labelKey.tr;

  static DepotAudience of(DepotListKind kind) =>
      values.firstWhere((a) => a.kind == kind);
}

/// Switches the list between SAP depots, Non-BP depots and the ones still
/// waiting for approval.
///
/// **A segmented control rather than another chip in the quick-access row.**
/// The chips already there — All, Sales org, Division, Recent, Favourites — all
/// slice the same population. This does not: it changes which population is on
/// screen, and putting it among them would make "Non-BP Depots" look like
/// another way to sort depots rather than a different list entirely.
///
/// Full width and split evenly so every option is always visible. A scrolling
/// row would let one hide off-screen, and a population that can be hidden is
/// a population nobody remembers to check. Labels wrap to two lines rather
/// than truncate, which Khmer needs.
class DepotAudienceFilter extends StatelessWidget {
  const DepotAudienceFilter({
    super.key,
    required this.selected,
    required this.onChanged,
    this.counts = const {},
  });

  final DepotAudience selected;
  final ValueChanged<DepotAudience> onChanged;

  /// Shown as a badge where supplied. A missing entry hides the badge rather
  /// than showing a zero, because "0" and "not counted yet" read identically
  /// and only one of them is worth acting on.
  final Map<DepotAudience, int> counts;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rr(4)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final audience in DepotAudience.values) ...[
              if (audience != DepotAudience.values.first)
                SizedBox(width: context.rw(4)),
              Expanded(
                child: _AudienceSegment(
                  label: audience.label,
                  count: counts[audience],
                  selected: selected == audience,
                  onTap: () => onChanged(audience),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AudienceSegment extends StatelessWidget {
  const _AudienceSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        // Centred: a neighbour's two-line label makes every segment taller.
        child: Center(
            child: Padding(
          // Scales with the label. Fixed padding around scaled type is what
          // makes a control look cramped once the tablet type scale kicks in.
          padding: EdgeInsets.symmetric(vertical: context.rh(9)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? scheme.onPrimary : colors.textSecondary,
                    fontSize: context.rsp(12.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (count != null) ...[
                SizedBox(width: context.rw(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(6),
                    vertical: context.rh(1),
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.onPrimary.withValues(alpha: 0.22)
                        : colors.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? scheme.onPrimary : colors.textSecondary,
                      fontSize: context.rsp(10),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        )),
      ),
    );
  }
}
