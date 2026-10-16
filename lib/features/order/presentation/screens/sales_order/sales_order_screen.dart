import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/create_sales_order.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/screens/success/order_success_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_line_tile.dart';
import 'package:steelforce/shared/widgets/back_to_home.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key, required this.quotation});

  static const routeName = 'order-sales-order';

  final Quotation quotation;

  @override
  State<SalesOrderScreen> createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  bool _submitting = false;

  Future<void> _create(BuildContext context) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final cartState = context.read<CartCubit>().state;
    final items =
        cartState is CartLoaded ? cartState.items : const <CartItem>[];

    final result = await sl<CreateSalesOrder>()(
        CreateSalesOrderParams(quotation: widget.quotation, items: items));

    if (!mounted) return;
    setState(() => _submitting = false);

    result.when(
      success: (order) =>
          Navigator.of(context).pushReplacement(MaterialPageRoute(
        settings: const RouteSettings(name: OrderSuccessScreen.routeName),
        builder: (_) => OrderSuccessScreen(salesOrder: order),
      )),
      failure: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        // Left side: Chevron Back + Sales Order Title
        title: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                color: colors.textPrimary,
                size: context.rsp(28),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                'orders.sales_order.title'.tr,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(17),
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Right side: Back to Home button
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.rw(16)),
            child: const BackToHomeButton(),
          ),
        ],
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          final items = state is CartLoaded ? state.items : const [];
          final subtotal = state is CartLoaded ? state.subtotal : 0.0;
          final discount = state is CartLoaded ? state.discount : 0.0;
          final tax = state is CartLoaded ? state.tax : 0.0;
          final total = state is CartLoaded ? state.total : 0.0;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  children: [
                    for (final item in items)
                      QuotationLineTile(
                        // Keyed by line: the quantity stepper inside holds a
                        // local value while its write is in flight, and an
                        // unkeyed list would pass it to whichever line slid
                        // into that position.
                        key: ValueKey(item.id),
                        item: item,
                        showStockStatus: true,
                        onQuantityChanged: (q) => context
                            .read<CartCubit>()
                            .updateQuantity(item.id, q),
                        onRemove: () =>
                            context.read<CartCubit>().removeItem(item.id),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.border))),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row('Subtotal', subtotal),
                      if (discount > 0) _Row('Discount', -discount),
                      _Row('Tax', tax),
                      Divider(color: colors.divider, height: 20),
                      _Row('orders.sales_order.title'.tr, total,
                          emphasize: true),
                      SizedBox(height: context.rh(12)),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (items.isEmpty || _submitting)
                              ? null
                              : () => _create(context),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.check_circle_outline_rounded,
                                  size: context.rr(20)),
                          label: Text('orders.sales_order.create_in_sap'.tr,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accentPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasize = false});
  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color:
                        emphasize ? colors.textPrimary : colors.textSecondary,
                    fontSize: emphasize ? 15 : 13,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500)),
          ),
          Text('\$${value.toStringAsFixed(2)}',
              style: TextStyle(
                  color: emphasize ? colors.accentPurple : colors.textPrimary,
                  fontSize: emphasize ? 16 : 13,
                  fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600)),
        ],
      ),
    );
  }
}
