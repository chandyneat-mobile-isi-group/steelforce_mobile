import 'dart:async';
import 'package:steelforce/core/config/feature_flags.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/presentation/widgets/add_hc_visit_dialog.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/add_depot_to_today.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_status_badge.dart';
import 'package:steelforce/features/order/presentation/screens/shop/shop_order_entry_screen.dart'; // Adjust path if needed

// Static fallback values used whenever real depot data is missing,
// mirroring the pattern used in StopCard.
const String _fallbackDepotCode = 'CUS-00000';
const String _fallbackTerritory = 'Phnom Penh';
const String _fallbackChannel = 'Wholesale';
const String _fallbackTier =
    'Silver'; // Fallback / mock field from depot entity

class DepotCard extends StatelessWidget {
  const DepotCard({
    super.key,
    required this.depot,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
    this.onCreateQuotationTap,
    this.onAddHcVisitTap,
    this.skipOffVisitCheck = false,
    this.seedSearchTerm,
  });

  final Depot depot;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onCreateQuotationTap;
  final VoidCallback? onAddHcVisitTap;
  final bool skipOffVisitCheck;
  final String? seedSearchTerm;

  void _navigateToOrderEntry(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: ShopOrderEntryScreen.routeName),
      builder: (_) => ShopOrderEntryScreen(
        depot: depot,
        skipOffVisitCheck: skipOffVisitCheck,
        seedSearchTerm: seedSearchTerm,
      ),
    ));
  }

  void _handleCreateQuotationTap(BuildContext context) {
    if (onCreateQuotationTap != null) {
      onCreateQuotationTap!();
    } else {
      _navigateToOrderEntry(context);
    }
  }

  /// The card's own fallback when no host handled the tap.
  ///
  /// Previously this opened the dialog and dropped the answer on the floor —
  /// the rep confirmed, saw a success message, and no visit was ever created.
  /// It now goes through the same path the detail screen uses.
  Future<void> _handleAddHcVisitTap(BuildContext context) async {
    if (onAddHcVisitTap != null) {
      onAddHcVisitTap!();
      return;
    }
    final sk = depot.adHocVisitCode;
    if (sk == null) return;
    final confirmed = await showAddHcVisitDialog(context, depot: depot);
    if (confirmed == null || !context.mounted) return;
    await addDepotToTodayVisits(
      context,
      depotId: depot.id,
      sk: sk,
      depotName: depot.shopName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final depotCode =
        depot.depotCode.isNotEmpty ? depot.depotCode : _fallbackDepotCode;
    final territory =
        depot.territory.isNotEmpty ? depot.territory : _fallbackTerritory;
    final cardRadius = context.rr(16);
    final padH = context.rw(16);
    final padV = context.rh(12);

    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: colors.border),
            boxShadow: colors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: name + trading status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      // Both languages are already on the entity, so a
                      // language switch re-resolves this line on the
                      // next rebuild — no re-query, no re-sync.
                      context.localized(depot.displayName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: context.rw(8)),
                  // Read straight off the entity — `DepotStatusBadge`
                  // resolves both the label and the colour from the stable
                  // `status` code, so an offline row reads in the current
                  // language rather than the one it was synced under.
                  //
                  // Beside the name on purpose: suspended, closed and
                  // credit-hold all mean "do not start writing an order", and
                  // a rep needs that before they tap through, not after. Same
                  // placement `shop_tile.dart` uses.
                  // Pinned into the card's top-right corner: it still takes
                  // its place in this row (so the name wraps short of it), and
                  // is then shifted out over the card's padding, inset by the
                  // 1px border.
                  //
                  // Width-capped, not bare: at large text scales an
                  // unconstrained badge overflows the card rather than
                  // ellipsizing. Not `Flexible` either — two flex children
                  // split the row in half and left the badge mid-card.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.rw(140)),
                    child: _CornerShift(
                      dx: padH - 1,
                      dy: -(padV - 1),
                      child: DepotStatusBadge(
                        status: depot.status,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rw(10),
                          vertical: context.rh(5),
                        ),
                        borderRadius: BorderRadiusDirectional.only(
                          topEnd: Radius.circular(cardRadius - 1),
                          bottomStart: Radius.circular(context.rr(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(6)),

              // Address / Territory line
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: context.rr(13),
                    color: colors.textSecondary,
                  ),
                  SizedBox(width: context.rw(4)),
                  Expanded(
                    child: Text(
                      territory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.rsp(11.5),
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(6)),

              // Middle Row: Territory + Channel + Tier Tags + Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tagging Section: Territory, Wholesale/Retail, Tier
                  Expanded(
                    child: Wrap(
                      spacing: context.rw(6),
                      runSpacing: context.rh(4),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _TagChip(
                          label: depotCode,
                          color: colors.surfaceSoft,
                          textColor: colors.textSecondary,
                        ),
                        // Plain text, not chips: these describe the depot,
                        // they are not controls. The territory is already on
                        // the line above, so it is not repeated here.
                        Text(
                          '$_fallbackChannel · $_fallbackTier',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons Section — kept as the two labeled
                  // depot actions (Create Quotation / Add HC Visit)
                  // instead of StopCard's basket/skip icon buttons.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (FeatureFlags.quotesAndOrders)
                        _QuickActionButton(
                          icon: Icons.request_quote_rounded,
                          label: 'my_visits.route_info.create_quotation'.tr,
                          color: scheme.primary,
                          onTap: () => _handleCreateQuotationTap(context),
                        ),
                      // Hidden until SAP reports the depot back: the ad hoc
                      // endpoint is keyed on its SAP code, and without one
                      // the tap could only ever answer "not found".
                      if (depot.adHocVisitCode != null) ...[
                        SizedBox(width: context.rw(8)),
                        _QuickActionButton(
                          icon: Icons.add_location_alt_rounded,
                          label: 'my_visits.ad_hoc.add_visit'.tr,
                          color: scheme.secondary,
                          onTap: () => unawaited(_handleAddHcVisitTap(context)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Moves [child] by ([dx], [dy]) without changing the space it takes in
/// layout — mirrored for right-to-left text.
class _CornerShift extends StatelessWidget {
  const _CornerShift({required this.dx, required this.dy, required this.child});

  final double dx;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Transform.translate(
      offset: Offset(rtl ? -dx : dx, dy),
      child: child,
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color, this.textColor});
  final String label;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(8),
        vertical: context.rh(4),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.rr(6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? context.appColors.textPrimary,
          fontSize: context.rsp(10.5),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Icon-in-circle action button, the same shape as StopCard's `_ActionButton`.
///
/// Icon only, so the card's last row is no taller than its text. The label is
/// not lost: it is the tooltip on long-press and what a screen reader reads.
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: Container(
            padding: EdgeInsets.all(context.rr(6)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: context.rr(22), color: color),
          ),
        ),
      ),
    );
  }
}
