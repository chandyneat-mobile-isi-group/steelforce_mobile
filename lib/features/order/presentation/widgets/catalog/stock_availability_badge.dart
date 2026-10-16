import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';

/// SAP's stock read for one material, as a badge.
///
/// ## Why this is not a number
///
/// `/materials/{material}/stock` answers a **band** — `"High"`, `"Medium"`,
/// `"Low"`, `"None"` — and never a quantity. There is no on-hand figure in the
/// payload to tap through to, which is the server's decision rather than a gap:
/// an exact count on a card is a number a rep reads as a promise the moment it
/// goes stale.
///
/// ## The states, and why they are these states
///
/// | [MaterialAvailability] | Badge | Meaning |
/// |---|---|---|
/// | absent | *nothing rendered* | never asked — the check costs a live SAP round trip and is spent on commitment |
/// | `checking` | spinner | asked, waiting |
/// | `available` + band | High / In stock / Low | SAP will accept the line, and this is how much |
/// | `available` + `none` | None on hand | SAP will accept the line, but there is nothing in the yard |
/// | `unavailable` | No stock | SAP will not accept the line |
/// | `unknown` | Stock unknown | the round trip failed — not a refusal |
///
/// Rendering "never asked" as "No stock" would be the worst mistake available
/// here: a rep would decline a sale on the strength of a question the handset
/// had not got round to asking.
///
/// ## Why `none` is not folded into "In stock"
///
/// SAP can answer `isSellable: true` with `band: "None"` — the ERP will take
/// the order, there is simply nothing on hand to fill it from today. That is a
/// real answer and a different one from [StockBand.unknown], which means SAP
/// reported no band at all. Both used to render as a green "In stock", which
/// told a rep there was stock when SAP had said the opposite. `none` now gets
/// the warning colour and its own label; `unknown` keeps the neutral fallback,
/// because inventing a level out of silence is the other half of the same
/// mistake.
class StockAvailabilityBadge extends StatelessWidget {
  const StockAvailabilityBadge({
    super.key,
    required this.availability,
    this.compact = false,
  });

  /// Null when this material has never been checked, in which case nothing
  /// renders at all.
  final MaterialAvailability? availability;

  /// Drops the label and keeps the dot, for a card too tight for words.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final verdict = availability;
    if (verdict == null) return const SizedBox.shrink();

    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final (String label, Color color) = switch (verdict.status) {
      MaterialStockStatus.checking => (
          'products.status.checking_stock'.tr,
          colors.textSecondary,
        ),
      // Sellable, so the band is what is worth saying. "Low" is a warning
      // about how much, not a refusal — the rep can still order and the `+`
      // stays live.
      MaterialStockStatus.available => switch (verdict.band) {
          StockBand.high => ('products.status.high_stock'.tr, colors.success),
          StockBand.medium => ('products.status.in_stock'.tr, colors.success),
          StockBand.low => ('products.status.low_stock'.tr, colors.warning),
          // Sellable, but the yard is empty. Warning rather than success, and
          // its own words rather than "In stock".
          StockBand.none => ('products.status.none_on_hand'.tr, colors.warning),
          // No band reported. Falls back to a plain "In stock" rather than
          // inventing a level out of silence.
          StockBand.unknown => ('products.status.in_stock'.tr, colors.success),
        },
      MaterialStockStatus.unavailable => (
          'products.status.no_stock'.tr,
          scheme.error,
        ),
      // Never asked, or the round trip failed. `canOrder` stays true for this
      // state, so the badge says what it knows without blocking anything.
      MaterialStockStatus.unknown => (
          'products.status.stock_unknown'.tr,
          colors.textSecondary,
        ),
    };

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(compact ? 5 : 6),
        vertical: context.rh(2),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.rr(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verdict.status == MaterialStockStatus.checking)
            SizedBox(
              width: context.rr(8),
              height: context.rr(8),
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            Container(
              width: context.rr(6),
              height: context.rr(6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (!compact) ...[
            SizedBox(width: context.rw(4)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: context.rsp(10.5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final tooltip = _tooltip(verdict);
    if (tooltip.isEmpty) return badge;

    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.longPress,
      child: badge,
    );
  }

  /// What a long press is worth showing, and nothing that isn't.
  ///
  /// A stock read carries no prose, so the useful detail is *where*: a rep told
  /// "High" still has to know which depot before promising anything. Where
  /// there are no plants, the band is all the endpoint said and the badge is
  /// already showing it — attaching a tooltip that repeats it is a control that
  /// rewards a long press with no new information.
  String _tooltip(MaterialAvailability verdict) {
    if (verdict.status == MaterialStockStatus.checking) return '';

    final plants = verdict.sellablePlants;
    if (plants.isNotEmpty) {
      return plants.map((p) => '${p.plant} · ${p.band.name}').join('\n');
    }

    if (verdict.band != StockBand.unknown) return '';

    // Only the sales-area check writes prose, and only when it has a cause to
    // name. A stock read leaves this empty and the tooltip is dropped.
    return verdict.reason;
  }
}
