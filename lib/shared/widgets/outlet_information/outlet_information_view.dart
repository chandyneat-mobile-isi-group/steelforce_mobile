import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/outlet_information/outlet_info_view_data.dart';

/// Minimum width before the detail cards split into two columns.
///
/// Deliberately not the `medium` breakpoint (600): an info row is
/// icon + label + value + action button, and a 6:5 split at 600-840pt leaves
/// ~290pt columns where every value ellipsizes. A tablet in portrait (820pt
/// and up) is the first size with genuine room for two columns.
const double _twoColumnMinWidth = 840;

/// The outlet/depot detail body, shared by the visit stop screen and the
/// depot directory's detail screen so both render one layout.
///
/// Deliberately *not* a `Scaffold`: each screen keeps its own app bar, and only
/// the visit flow has a bottom "Start Visit" bar. This widget owns the scroll
/// view and the responsive column split, nothing above them.
class OutletInformationView extends StatelessWidget {
  const OutletInformationView({
    super.key,
    required this.data,
    this.distanceLabel,
    this.onPhoneTap,
    this.onLocationTap,
    this.onOrderHistoryTap,
    this.trailing = const <Widget>[],
  });

  final OutletInfoViewData data;

  /// Pre-formatted "1.2 km" style label. Passed in rather than computed here
  /// because it depends on a live location stream that only the visit flow
  /// runs — the directory has no fix to measure from.
  final String? distanceLabel;

  final void Function(String phone)? onPhoneTap;
  final void Function(double latitude, double longitude)? onLocationTap;
  final VoidCallback? onOrderHistoryTap;

  /// Extra cards appended after the shared ones — the depot screen's
  /// timeline, for instance. Spaced by this widget so callers never hand-tune
  /// the gap and drift apart from each other.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final isTwoColumn = MediaQuery.sizeOf(context).width >= _twoColumnMinWidth;

    final infoCard = OutletDetailsCard(
      data: data,
      distanceLabel: distanceLabel,
      onPhoneTap: onPhoneTap,
      onLocationTap: onLocationTap,
    );

    // Right column on tablets, stacked below on phones. Built once and used by
    // both branches so the two layouts cannot drift.
    final secondary = <Widget>[
      if (data.promotions case final promotions?)
        OutletPromotionsCard(promotions: promotions),
      if (data.hasSalesHistory)
        OutletSalesHistoryCard(
          data: data,
          onOrderHistoryTap: onOrderHistoryTap,
        ),
      ...trailing,
    ];

    return ResponsiveContentFrame(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          context.rh(12),
          context.pagePadding,
          context.rh(24),
        ),
        children: [
          OutletHeroCard(displayName: data.displayName, code: data.code),
          SizedBox(height: context.rh(16)),
          if (isTwoColumn)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: infoCard),
                SizedBox(width: context.rw(16)),
                Expanded(
                  flex: 5,
                  child: Column(children: _spaced(context, secondary, 16)),
                ),
              ],
            )
          else
            Column(
              children: [
                infoCard,
                ..._leadingSpaced(context, secondary, 14),
              ],
            ),
        ],
      ),
    );
  }

  /// Inserts gaps *between* children — no leading or trailing gap.
  static List<Widget> _spaced(
      BuildContext context, List<Widget> children, double gap) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(SizedBox(height: context.rh(gap)));
      out.add(children[i]);
    }
    return out;
  }

  /// Inserts a gap *before* every child, for appending after an existing one.
  static List<Widget> _leadingSpaced(
      BuildContext context, List<Widget> children, double gap) {
    return [
      for (final child in children) ...[
        SizedBox(height: context.rh(gap)),
        child,
      ],
    ];
  }
}

/// Shop name + depot code, at the top of the detail body.
class OutletHeroCard extends StatelessWidget {
  const OutletHeroCard({
    super.key,
    required this.displayName,
    required this.code,
  });

  final LocalizedText displayName;
  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return _OutletCard(
      padding: EdgeInsets.all(context.rr(16)),
      child: Row(
        children: [
          Container(
            width: context.rr(52),
            height: context.rr(52),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(context.rr(12)),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: scheme.primary,
              size: context.rr(26),
            ),
          ),
          SizedBox(width: context.rw(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.localized(displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(18),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: context.rh(4)),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rw(6),
                        vertical: context.rh(2),
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(context.rr(6)),
                      ),
                      child: Text(
                        'CUS CODE',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: context.rsp(10),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: context.rw(6)),
                    Expanded(
                      child: Text(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: context.rsp(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Outlet Details & Location" — identity, contact and position.
class OutletDetailsCard extends StatelessWidget {
  const OutletDetailsCard({
    super.key,
    required this.data,
    this.distanceLabel,
    this.onPhoneTap,
    this.onLocationTap,
  });

  final OutletInfoViewData data;
  final String? distanceLabel;
  final void Function(String phone)? onPhoneTap;
  final void Function(double latitude, double longitude)? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final phone = data.phone;
    final lat = data.latitude;
    final lng = data.longitude;

    // Built as specs rather than widgets so the divider on the final visible
    // row can be suppressed. Rows are conditional now that two sources with
    // different field coverage share this card, so `last` cannot be hardcoded
    // at a call site the way it was when only a route stop rendered here.
    final rows = <_InfoRowSpec>[
      if (data.outletId case final v?)
        _InfoRowSpec(
            icon: Icons.tag_rounded, label: 'Outlet ID (BP SAP)', value: v),
      if (data.outletType case final v?)
        _InfoRowSpec(
            icon: Icons.store_outlined, label: 'Outlet Type', value: v),
      if (data.outletTier case final v?)
        _InfoRowSpec(
            icon: Icons.workspace_premium_outlined,
            label: 'Outlet Tier',
            value: v),
      if (data.outletAction case final v?)
        _InfoRowSpec(
            icon: Icons.alt_route_rounded, label: 'Outlet Action', value: v),
      if (data.contactPerson case final v?)
        _InfoRowSpec(
            icon: Icons.person_outline_rounded,
            label: 'Owner / Contact Person (SAP)',
            value: v),
      if (data.assignedRep case final v?)
        _InfoRowSpec(
            icon: Icons.person_pin_circle_outlined,
            label: 'Assigned Rep',
            value: v),
      if (phone != null && phone.isNotEmpty)
        _InfoRowSpec(
          icon: Icons.call_outlined,
          label: 'Phone Number (SAP)',
          value: phone,
          onTap: onPhoneTap == null ? null : () => onPhoneTap!(phone),
          action: onPhoneTap == null
              ? null
              : _ActionIconButton(
                  icon: Icons.phone_forwarded_rounded,
                  color: Colors.green,
                  onPressed: () => onPhoneTap!(phone),
                ),
        ),
      if (data.telegram case final v?)
        _InfoRowSpec(icon: Icons.send_rounded, label: 'Telegram', value: v),
      if (data.email case final v?)
        _InfoRowSpec(icon: Icons.email_outlined, label: 'Email', value: v),
      if (data.address case final v?)
        _InfoRowSpec(
            icon: Icons.location_on_outlined,
            label: 'Address Line (SAP)',
            value: v),
      if (data.taxNumber case final v?)
        _InfoRowSpec(
            icon: Icons.receipt_outlined, label: 'Tax / VAT No.', value: v),
      if (data.hasCoordinates && lat != null && lng != null)
        _InfoRowSpec(
          icon: Icons.my_location_rounded,
          label: 'Lat & Long (SAP)',
          value: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
          onTap: onLocationTap == null ? null : () => onLocationTap!(lat, lng),
          action: onLocationTap == null
              ? null
              : _ActionIconButton(
                  icon: Icons.map_rounded,
                  color: Colors.blue,
                  onPressed: () => onLocationTap!(lat, lng),
                ),
        ),
      if (distanceLabel case final v?)
        _InfoRowSpec(
            icon: Icons.straighten_rounded, label: 'Distance', value: v),
    ];

    return _OutletCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.rr(16),
        vertical: context.rh(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OutletSectionHeader(title: 'Outlet Details & Location'),
          ..._renderRows(rows),
        ],
      ),
    );
  }
}

/// "Sales History Detail" — the commercial position, all SAP-owned.
class OutletSalesHistoryCard extends StatelessWidget {
  const OutletSalesHistoryCard({
    super.key,
    required this.data,
    this.onOrderHistoryTap,
  });

  final OutletInfoViewData data;
  final VoidCallback? onOrderHistoryTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final rows = <_InfoRowSpec>[
      if (data.paymentStatus case final v?)
        _InfoRowSpec(
            icon: Icons.verified_user_outlined,
            label: 'Payment/Credit Status',
            value: v),
      if (data.creditLimit case final v?)
        _InfoRowSpec(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Credit Limit (SAP)',
            value: v),
      if (data.paymentTerm case final v?)
        _InfoRowSpec(
            icon: Icons.calendar_month_outlined,
            label: 'Payment Term (SAP)',
            value: v),
      if (data.lifetimeValue case final v?)
        _InfoRowSpec(
            icon: Icons.payments_outlined, label: 'Lifetime Value', value: v),
      if (data.totalOrders case final v?)
        _InfoRowSpec(
            icon: Icons.shopping_bag_outlined, label: 'Total Orders', value: v),
      if (data.averageRevenuePerOrder case final v?)
        _InfoRowSpec(
            icon: Icons.trending_up_rounded,
            label: 'Avg Rev per Order',
            value: v),
      if (data.latestOrderDate case final v?)
        _InfoRowSpec(
            icon: Icons.history_toggle_off_rounded,
            label: 'Latest Order Date (SAP)',
            value: v),
      if (data.openOpportunities case final v?)
        _InfoRowSpec(
            icon: Icons.trending_up_outlined,
            label: 'Open Opportunities',
            value: v),
      if (data.lastSynced case final v?)
        _InfoRowSpec(
            icon: Icons.update_rounded, label: 'Last Synced (SAP)', value: v),
      if (onOrderHistoryTap != null)
        _InfoRowSpec(
          icon: Icons.receipt_long_rounded,
          label: 'Order History (SAP)',
          value: 'Tap to view outlet orders history',
          onTap: onOrderHistoryTap,
          action: Icon(
            Icons.arrow_forward_ios_rounded,
            size: context.rr(14),
            color: colors.textSecondary,
          ),
        ),
    ];

    return _OutletCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.rr(16),
        vertical: context.rh(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OutletSectionHeader(title: 'Sales History Detail'),
          ..._renderRows(rows),
        ],
      ),
    );
  }
}

/// "Promotions" — counts by promotion mechanic.
class OutletPromotionsCard extends StatelessWidget {
  const OutletPromotionsCard({super.key, required this.promotions});

  final OutletPromotionSummary promotions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return _OutletCard(
      padding: EdgeInsets.all(context.rr(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible so the title block yields to the chevron rather than
              // overflowing once the type scales up on a tablet.
              Flexible(
                child: Row(
                  children: [
                    Icon(Icons.local_offer_outlined,
                        size: context.rr(20), color: colors.textPrimary),
                    SizedBox(width: context.rw(8)),
                    Flexible(
                      child: Text(
                        'Promotions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(15),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: context.rw(8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rw(8),
                        vertical: context.rh(2),
                      ),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(context.rr(10)),
                      ),
                      child: Text(
                        '${promotions.total}',
                        style: TextStyle(
                          fontSize: context.rsp(11),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: context.rr(24),
                color: colors.textSecondary,
              ),
            ],
          ),
          SizedBox(height: context.rh(14)),
          Wrap(
            spacing: context.rw(8),
            runSpacing: context.rh(8),
            children: [
              _PromoBadge(
                  label: 'ON-INVOICE (${promotions.onInvoice})',
                  color: Colors.blue.shade100,
                  textColor: Colors.blue.shade900),
              _PromoBadge(
                  label: 'OFF-INVOICE (${promotions.offInvoice})',
                  color: Colors.grey.shade200,
                  textColor: Colors.grey.shade700),
              _PromoBadge(
                  label: 'CONTRACT (${promotions.contract})',
                  color: Colors.teal.shade100,
                  textColor: Colors.teal.shade900),
            ],
          )
        ],
      ),
    );
  }
}

/// The card shell every section on this screen uses. Public so callers passing
/// `trailing` sections match the surrounding cards instead of approximating
/// them.
class OutletCard extends StatelessWidget {
  const OutletCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => _OutletCard(
        padding: padding ??
            EdgeInsets.symmetric(
              horizontal: context.rr(16),
              vertical: context.rh(8),
            ),
        child: child,
      );
}

class _OutletCard extends StatelessWidget {
  const _OutletCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: child,
    );
  }
}

class OutletSectionHeader extends StatelessWidget {
  const OutletSectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(10)),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: context.rsp(14.5),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// One row's content, before it knows whether it is the last visible row.
class _InfoRowSpec {
  const _InfoRowSpec({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.action,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? action;
}

List<Widget> _renderRows(List<_InfoRowSpec> specs) => [
      for (var i = 0; i < specs.length; i++)
        _InfoRow(
          icon: specs[i].icon,
          label: specs[i].label,
          value: specs[i].value,
          onTap: specs[i].onTap,
          actionWidget: specs[i].action,
          last: i == specs.length - 1,
        ),
    ];

class _PromoBadge extends StatelessWidget {
  const _PromoBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(12),
        vertical: context.rh(6),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.rr(8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: context.rsp(11),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatefulWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
    this.actionWidget,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;
  final Widget? actionWidget;
  final VoidCallback? onTap;

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isInteractive = widget.onTap != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor:
          isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: widget.onTap != null
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(context.rr(10)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            vertical: context.rh(10),
            horizontal: _isHovered ? context.rw(8) : 0,
          ),
          decoration: BoxDecoration(
            color: _isHovered && isInteractive
                ? colors.border.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(context.rr(10)),
            border: widget.last
                ? null
                : Border(
                    bottom: BorderSide(
                      color: colors.border,
                      width: 0.6,
                    ),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  widget.icon,
                  size: context.rr(20),
                  color: widget.onTap != null
                      ? Theme.of(context).colorScheme.primary
                      : colors.textSecondary,
                ),
              ),
              SizedBox(width: context.rw(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(11.5),
                      ),
                    ),
                    SizedBox(height: context.rh(2)),
                    Text(
                      widget.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(13.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.actionWidget != null) widget.actionWidget!,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatefulWidget {
  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: IconButton(
          icon: Icon(widget.icon, color: widget.color, size: context.rr(22)),
          constraints: BoxConstraints(
            minWidth: context.rr(40),
            minHeight: context.rr(40),
          ),
          padding: EdgeInsets.all(context.rr(8)),
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onPressed();
          },
        ),
      ),
    );
  }
}
