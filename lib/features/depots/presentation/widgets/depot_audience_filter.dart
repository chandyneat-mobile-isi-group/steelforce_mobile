import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Which population the depots screen is showing.
enum DepotAudience {
  depots('Depots'),
  nonBpDepots('Non-BP Depots');

  const DepotAudience(this.label);

  final String label;
}

/// Switches the list between SAP depots and non-bp-depots.
///
/// **A two-segment control rather than another chip in the quick-access row.**
/// The chips already there — All, Sales org, Division, Recent, Favourites — all
/// slice the same population. This does not: it changes which population is on
/// screen, and putting it among them would make "Non-BP Depots" look like a
/// sixth way to sort depots rather than a different list entirely. A rep who
/// misreads that ends up hunting for a shop in a list it was never in.
///
/// Full width and split in two so both options are always visible. A scrolling
/// row would let one of the two hide off-screen, and a population that can be
/// hidden is a population nobody remembers to check.
class DepotAudienceFilter extends StatelessWidget {
  const DepotAudienceFilter({
    super.key,
    required this.selected,
    required this.onChanged,
    this.depotCount,
    this.nonBpDepotCount,
  });

  final DepotAudience selected;
  final ValueChanged<DepotAudience> onChanged;

  /// Shown as a badge when supplied. Null hides the badge rather than showing a
  /// zero, because "0" and "not counted yet" read identically and only one of
  /// them is worth acting on.
  final int? depotCount;
  final int? nonBpDepotCount;

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
      child: Row(
        children: [
          Expanded(
            child: _AudienceSegment(
              label: DepotAudience.depots.label,
              count: depotCount,
              selected: selected == DepotAudience.depots,
              onTap: () => onChanged(DepotAudience.depots),
            ),
          ),
          SizedBox(width: context.rw(4)),
          Expanded(
            child: _AudienceSegment(
              label: DepotAudience.nonBpDepots.label,
              count: nonBpDepotCount,
              selected: selected == DepotAudience.nonBpDepots,
              onTap: () => onChanged(DepotAudience.nonBpDepots),
            ),
          ),
        ],
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
                  maxLines: 1,
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
        ),
      ),
    );
  }
}
