import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/presentation/widgets/sales_order/sales_order_status_chip.dart';
import 'package:steelforce/shared/widgets/back_to_home.dart';

/// One sales order in full: who it is for, what is on it, and what it came to.
///
/// Read-only by design. An order is a committed document — editing it is a
/// different operation with its own approval path, and offering a stray edit
/// control here would imply the rep can change a figure SAP already holds.
class SalesOrderDetailScreen extends StatelessWidget {
  const SalesOrderDetailScreen({super.key, required this.order});

  static const routeName = 'order-sales-order-detail';

  final SalesOrder order;

  static Future<void> open(BuildContext context, SalesOrder order) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: routeName),
          builder: (_) => LocalizedBuilder(
            builder: (_) => SalesOrderDetailScreen(order: order),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final language = context.languageCode;
    final money = NumberFormat.currency(locale: language, symbol: r'$');
    final date = DateFormat.yMMMMd(language).add_jm().format(order.createdAt);

    final party = order.shopName?.trim().isNotEmpty == true
        ? order.shopName!
        : (order.leadDisplayName?.trim().isNotEmpty == true
            ? order.leadDisplayName!
            : 'orders.sales_order.unnamed_party'.tr);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        // Back button in `leading`, not packed into `title` with a Row. The
        // Row form overflows at large text scales: AppBar sizes `actions`
        // first, and what is left over can be narrower than an IconButton's
        // 48dp minimum, which cannot shrink to fit.
        leading: IconButton(
          tooltip: 'common.back'.tr,
          icon: Icon(Icons.chevron_left_rounded,
              color: colors.textPrimary, size: context.rsp(28)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'orders.sales_order.detail_title'.tr,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.rw(16)),
            child: const BackToHomeButton(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              context.rw(16), context.rh(4), context.rw(16), context.rh(28)),
          children: [
            _Header(order: order, party: party, date: date),
            SizedBox(height: context.rh(18)),
            _SectionTitle('orders.sales_order.section_items'.tr),
            SizedBox(height: context.rh(8)),
            if (order.lines.isEmpty)
              _EmptyLines()
            else
              for (final line in order.lines)
                _LineTile(key: ValueKey(line.id), line: line, money: money),
            SizedBox(height: context.rh(18)),
            _SectionTitle('orders.sales_order.section_totals'.tr),
            SizedBox(height: context.rh(8)),
            _TotalsCard(order: order, money: money),
            SizedBox(height: context.rh(18)),
            _SectionTitle('orders.sales_order.section_reference'.tr),
            SizedBox(height: context.rh(8)),
            _ReferenceCard(order: order),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order, required this.party, required this.date});

  final SalesOrder order;
  final String party;
  final String date;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rr(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(18)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wraps rather than clipping: an order id plus a Khmer status label
          // will not share one line at large text scales.
          Wrap(
            spacing: context.rw(10),
            runSpacing: context.rh(8),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                order.id,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(19),
                  fontWeight: FontWeight.w900,
                ),
              ),
              SalesOrderStatusChip(status: order.status),
            ],
          ),
          SizedBox(height: context.rh(10)),
          _IconLine(icon: Icons.storefront_rounded, text: party),
          SizedBox(height: context.rh(6)),
          _IconLine(icon: Icons.event_rounded, text: date),
          if (order.offVisitReason != null) ...[
            SizedBox(height: context.rh(12)),
            _OffVisitNotice(reason: order.offVisitReason!.name),
          ],
        ],
      ),
    );
  }
}

/// An order raised away from the depot's location is a compliance-relevant
/// fact, so it is surfaced on the order itself rather than buried in a log.
class _OffVisitNotice extends StatelessWidget {
  const _OffVisitNotice({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(12), vertical: context.rh(10)),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: colors.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: context.rr(16), color: colors.warning),
          SizedBox(width: context.rw(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'orders.shop.off_visit_warning'.tr,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(12),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: context.rh(2)),
                Text(
                  reason,
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: context.rsp(11.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon-plus-label row. The icon repeats the meaning the label carries, so
/// the row still reads when the label is truncated.
class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.rh(2)),
          child: Icon(icon, size: context.rr(14), color: colors.iconMuted),
        ),
        SizedBox(width: context.rw(7)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(12.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({super.key, required this.line, required this.money});

  final CartItem line;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Quantities are decimals (steel sells by weight and length), so a bare
    // toString would render `12.0` for twelve. intl keeps it locale-correct
    // and drops the pointless trailing zero.
    final quantity =
        NumberFormat.decimalPattern(context.languageCode).format(line.quantity);

    return Container(
      margin: EdgeInsets.only(bottom: context.rh(8)),
      padding: EdgeInsets.all(context.rr(13)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.localized(line.product.displayName),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(13.5),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: context.rh(3)),
          Text(
            line.skuCode,
            style: TextStyle(color: colors.textHint, fontSize: context.rsp(11)),
          ),
          if (line.isCustomized) ...[
            SizedBox(height: context.rh(6)),
            _CustomizedBadge(),
          ],
          SizedBox(height: context.rh(9)),
          Wrap(
            spacing: context.rw(10),
            runSpacing: context.rh(4),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$quantity ${line.unit} × ${money.format(line.unitPrice)}',
                style: TextStyle(
                    color: colors.textSecondary, fontSize: context.rsp(12)),
              ),
              if (line.discountPercent > 0)
                Text(
                  '−${NumberFormat.decimalPattern(context.languageCode).format(line.discountPercent)}%',
                  style: TextStyle(
                    color: colors.success,
                    fontSize: context.rsp(12),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          SizedBox(height: context.rh(8)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              money.format(line.lineTotal),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(7), vertical: context.rh(2)),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.rr(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune_rounded, size: context.rr(11), color: colors.info),
          SizedBox(width: context.rw(4)),
          Text(
            'orders.sales_order.customized'.tr,
            style: TextStyle(
              color: colors.info,
              fontSize: context.rsp(10.5),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.order, required this.money});

  final SalesOrder order;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rr(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _AmountRow(
              'orders.sales_order.subtotal'.tr, money.format(order.subtotal)),
          if (order.discount > 0)
            _AmountRow('orders.sales_order.discount'.tr,
                '−${money.format(order.discount)}',
                valueColor: colors.success),
          _AmountRow('orders.sales_order.tax'.tr, money.format(order.tax)),
          Divider(color: colors.divider, height: context.rh(22)),
          _AmountRow(
              'orders.sales_order.order_total'.tr, money.format(order.total),
              emphasize: true),
        ],
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.order});
  final SalesOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rr(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _AmountRow('orders.quotation.builder_title'.tr, order.quotationId),
          _AmountRow('orders.sales_order.sap_status'.tr, order.sapStatus),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value,
      {this.emphasize = false, this.valueColor});

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasize ? colors.textPrimary : colors.textSecondary,
                fontSize: context.rsp(emphasize ? 14 : 12.5),
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: context.rw(12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ??
                    (emphasize ? colors.accentPurple : colors.textPrimary),
                fontSize: context.rsp(emphasize ? 16 : 13),
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.appColors.textSecondary,
        fontSize: context.rsp(12),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _EmptyLines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(context.rr(16)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        'orders.sales_order.no_lines'.tr,
        style:
            TextStyle(color: colors.textSecondary, fontSize: context.rsp(12.5)),
      ),
    );
  }
}
