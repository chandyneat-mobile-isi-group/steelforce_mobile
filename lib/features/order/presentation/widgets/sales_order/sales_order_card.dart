import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/presentation/widgets/sales_order/sales_order_status_chip.dart';

/// One row in the sales-order list: who it is for, when, how much, and whether
/// it is committed[cite: 5].
///
/// Designed with a modern, relaxed aesthetic using soft shadows, clear visual
/// hierarchy, and distinct metadata chips for easy scanning.
class SalesOrderCard extends StatelessWidget {
  const SalesOrderCard({super.key, required this.order, required this.onTap});

  final SalesOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    // Locale-aware, via intl (FS-LOC-6) — never a hand-built date string[cite: 5].
    final language = context.languageCode;
    final date = DateFormat.yMMMd(language).add_jm().format(order.createdAt);
    final total = NumberFormat.currency(locale: language, symbol: r'$')
        .format(order.total);

    // Falls through depot → lead → an explicit "unnamed" key rather than
    // rendering a blank line[cite: 5].
    final party = order.shopName?.trim().isNotEmpty == true
        ? order.shopName!
        : (order.leadDisplayName?.trim().isNotEmpty == true
            ? order.leadDisplayName!
            : 'orders.sales_order.unnamed_party'.tr);

    return Semantics(
      button: true,
      label: '${order.id}, $party, $total',
      child: Padding(
        padding: EdgeInsets.only(
            bottom:
                context.rh(14)), // Slightly larger padding for a relaxed layout
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(context.rr(20)),
            // Modern, relaxed soft shadow instead of a harsh border
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            // Ultra-thin, barely-there border for edge definition on white themes
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(context.rr(20)),
              child: Padding(
                padding:
                    EdgeInsets.all(context.rr(16)), // Generous inner padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER: ID & Status ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            order.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(14),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3, // Modern typography spacing
                            ),
                          ),
                        ),
                        SizedBox(width: context.rw(8)),
                        SalesOrderStatusChip(
                            status: order.status, compact: true),
                      ],
                    ),

                    SizedBox(height: context.rh(14)),

                    // --- BODY: Visual Aid & Depot Name ---
                    Row(
                      children: [
                        // Soft avatar icon for quick visual recognition
                        Container(
                          padding: EdgeInsets.all(context.rr(8)),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: scheme.primary,
                            size: context.rr(18),
                          ),
                        ),
                        SizedBox(width: context.rw(12)),
                        Expanded(
                          child: Text(
                            party,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(15.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: context.rh(14)),

                    // --- METADATA: Soft Pill Chips ---
                    // Wraps instead of overflowing: at 200% font scale
                    // (FS-A11Y-2) the date and total cannot share one line[cite: 5].
                    Wrap(
                      spacing: context.rw(8),
                      runSpacing: context.rh(8),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetaChip(
                          icon: Icons.calendar_today_rounded,
                          text: date,
                        ),
                        _MetaChip(
                          icon: Icons.inventory_2_rounded,
                          text: 'orders.items_count'
                              .trParams({'count': order.lines.length}),
                        ),
                      ],
                    ),

                    SizedBox(height: context.rh(16)),
                    Divider(
                        color: colors.divider.withValues(alpha: 0.5),
                        height: 1),
                    SizedBox(height: context.rh(12)),

                    // --- FOOTER: Total Amount ---
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'orders.sales_order.order_total'.tr,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          total,
                          style: TextStyle(
                            color: colors
                                .accentPurple, // Maintaining your accent color[cite: 5]
                            fontSize: context.rsp(17),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Upgraded _Meta widget: Now renders as a soft pill/chip for better visual
/// grouping and a modern look.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(10),
        vertical: context.rh(6),
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceSoft, // Use a soft gray/background color from your theme
        borderRadius: BorderRadius.circular(context.rr(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rr(13), color: colors.textSecondary),
          SizedBox(width: context.rw(6)),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(11.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
