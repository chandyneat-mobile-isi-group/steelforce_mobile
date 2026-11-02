import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/presentation/widgets/add_hc_visit_dialog.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/add_depot_to_today.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_status_badge.dart';
import 'package:steelforce/features/order/presentation/screens/shop/shop_order_entry_screen.dart'; // Adjust path if needed

/// The list card shows only name, address, territory, channel and status. Everything else the list feed carries (code, coordinates, rep,
/// branch) is kept on the entity for the detail screen.
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
    this.quotationCoachAnchor,
    this.showQuotationAction = true,
    this.adHocAllowed = true,
    this.onAdHocAdded,
  });

  final Depot depot;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onCreateQuotationTap;
  final VoidCallback? onAddHcVisitTap;
  final bool skipOffVisitCheck;
  final String? seedSearchTerm;

  /// App Coach anchor id for the Create Quotation button, if this card carries
  /// one (`CoachKeys`). Adds no layout.
  final String? quotationCoachAnchor;

  /// Off for Non-BP depots and the ones awaiting approval: neither trades.
  final bool showQuotationAction;

  /// False once this outlet had its ad hoc visit today: the action shows
  /// grey. Still tappable, so the rep is told why it cannot be added.
  final bool adHocAllowed;

  /// Runs once an ad hoc visit was added from this card.
  final VoidCallback? onAdHocAdded;

  Widget _withQuotationAnchor(Widget button) => switch (quotationCoachAnchor) {
        final id? => CoachKeys.wrap(id, child: button),
        null => button,
      };

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

  /// The card's own fallback when no host handled the tap: confirm, then
  /// `POST /mobile/plans/ad-hoc`, which reports what actually happened.
  Future<void> _handleAddHcVisitTap(BuildContext context) async {
    if (onAddHcVisitTap != null) {
      onAddHcVisitTap!();
      return;
    }
    if (!await adHocVisitsAvailable(context, depot: depot) ||
        !context.mounted) {
      return;
    }
    final confirmed = await showAddHcVisitDialog(context, depot: depot);
    if (confirmed == null || !context.mounted) return;
    if (await startAdHocVisitAt(context, depot)) onAdHocAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    // Exactly what the depots API sent; "Null" when it sent nothing —
    // never a made-up or placeholder value.
    String shown(String? value) => (value?.trim().isNotEmpty ?? false)
        ? value!.trim()
        : 'depots.detail.null_value'.tr;
    final name = shown(context.localized(depot.displayName));
    final address = shown(depot.address);
    // The same fields as a visit plan card, from the depots API: name,
    // address, then territory · channel · tier. Everything else is on the
    // details screen.
    final facts = [
      depot.territory,
      depot.distributionChannel,
      depot.profile?.tier,
    ].map(shown).join(' · ');
    final cardRadius = context.rr(16);
    final padH = context.rw(16);
    final padV = context.rh(12);

    return InkWell(
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
                    name,
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

            // Address line
            ...[
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
                      address,
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
              SizedBox(height: context.rh(4)),
            ],
            // Territory · channel · tier, then the actions.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    facts,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Action Buttons Section — kept as the two labeled
                // depot actions (Create Quotation / Add HC Visit)
                // instead of StopCard's basket/skip icon buttons.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showQuotationAction)
                      _withQuotationAnchor(
                        _QuickActionButton(
                          icon: Icons.request_quote_rounded,
                          label: 'my_visits.route_info.create_quotation'.tr,
                          color: scheme.primary,
                          onTap: () => _handleCreateQuotationTap(context),
                        ),
                      ),
                    // A depot by its code, a Non-BP depot by its id; hidden
                    // while awaiting approval, which the server cannot find.
                    if (depot.adHocOutlet != null) ...[
                      SizedBox(width: context.rw(8)),
                      _QuickActionButton(
                        icon: Icons.add_location_alt_rounded,
                        label: 'my_visits.ad_hoc.add_visit'.tr,
                        color: adHocAllowed
                            ? scheme.secondary
                            : colors.textSecondary,
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
