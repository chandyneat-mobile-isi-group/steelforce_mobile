import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/cart_summary_bar.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/find_new_product_button.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class GuidedCartFooter extends StatelessWidget {
  const GuidedCartFooter({
    super.key,
    required this.onTap,
    required this.onFindNewProduct,
    required this.showFindNew,
  });

  final VoidCallback? onTap;
  final VoidCallback onFindNewProduct;
  final bool showFindNew;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        final items =
            cartState is CartLoaded ? cartState.items : const <CartItem>[];
        if (items.isEmpty) return const SizedBox(width: double.infinity);

        final totalQuantity =
            items.fold<double>(0, (sum, item) => sum + item.quantity);
        // Null as soon as one line is unpriced — see [CartSummaryBar.subtotal].
        final subtotal = cartState is CartLoaded
            ? (items.hasPendingPricing ? null : cartState.subtotal)
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CartSummaryBar(
              lineCount: items.length,
              totalQuantity: totalQuantity,
              subtotal: subtotal,
              onTap: onTap,
            ),
            // Only offered once something is in the quotation and products are
            // on screen — before that there is nothing to move on from.
            if (showFindNew) ...[
              SizedBox(height: context.rh(10)),
              FindNewProductButton(onPressed: onFindNewProduct),
            ],
          ],
        );
      },
    );
  }
}
