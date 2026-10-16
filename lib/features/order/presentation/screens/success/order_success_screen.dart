import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart'; // 👈 ADJUST THIS PATH TO YOUR THEME EXTENSION FILE
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen(
      {super.key, required this.salesOrder, this.onDone, this.onNewOrder});

  static const routeName = 'order-success';

  final SalesOrder salesOrder;
  final VoidCallback? onDone;
  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.14),
                            shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded,
                            color: colors.success, size: context.rr(44)),
                      ),
                    ),
                    SizedBox(height: context.rh(20)),
                    Center(
                      child: Text(salesOrder.id,
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(22),
                              fontWeight: FontWeight.w900)),
                    ),
                    SizedBox(height: context.rh(4)),
                    Center(
                      child: Text(
                          salesOrder.shopName ??
                              salesOrder.leadDisplayName ??
                              '',
                          style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(13))),
                    ),
                    SizedBox(height: context.rh(24)),
                    Container(
                      padding: EdgeInsets.all(context.rr(16)),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border)),
                      child: Column(
                        children: [
                          _Row('orders.sales_order.title'.tr,
                              '\$${salesOrder.total.toStringAsFixed(2)}',
                              emphasize: true),
                          if (salesOrder.offVisitReason != null)
                            _Row(
                                'orders.shop.off_visit_warning'.tr,
                                salesOrder.offVisitReason!
                                    .name), // 👈 CHANGED FROM localizedLabel TO name TO RESOLVE COMPILER ERROR
                          _Row('orders.quotation.builder_title'.tr,
                              salesOrder.quotationId),
                          _Row('orders.sales_order.sap_status'.tr,
                              salesOrder.sapStatus),
                        ],
                      ),
                    ),
                    SizedBox(height: context.rh(20)),
                    Text('orders.success.sap_message'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(12.5),
                            height: 1.4)),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone ??
                      () => Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('orders.success.done'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              if (onNewOrder != null) ...[
                SizedBox(height: context.rh(10)),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: onNewOrder,
                      child: Text('orders.success.new_order'.tr)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12.5)))),
          Text(value,
              style: TextStyle(
                color: emphasize ? colors.accentPurple : colors.textPrimary,
                fontSize: emphasize ? 16 : 13,
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              )),
        ],
      ),
    );
  }
}
