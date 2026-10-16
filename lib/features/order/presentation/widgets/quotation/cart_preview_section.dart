import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/platform/storage/local_files.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/demo_cart_promotions.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/stock_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/cart_promotion_badge.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/promotion_detail_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/line_discount_chips.dart';
import 'package:steelforce/features/order/presentation/widgets/catalog/stock_availability_badge.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/cart_quantity_stepper.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/manual_price_input_sheet.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The cart, reviewed before saving — and the one place stock is checked
/// eagerly rather than on commitment.
///
/// Everywhere else a check is spent only when a rep singles a material out,
/// because a scrolling catalog would otherwise cost a live ERP round trip per
/// card. The cart is the opposite case: every line here is already a
/// commitment, there are rarely more than a dozen, and the rep is about to
/// turn them into a quotation. Finding out at that moment that SAP will not
/// accept one of them is the entire point.
class CartPreviewSection extends StatefulWidget {
  const CartPreviewSection({super.key});

  @override
  State<CartPreviewSection> createState() => _CartPreviewSectionState();
}

class _CartPreviewSectionState extends State<CartPreviewSection> {
  @override
  void initState() {
    super.initState();
    // After the first frame, so the read happens against a mounted tree rather
    // than mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAll(context.read<CartCubit>().state);
    });
  }

  /// `ensure` deduplicates in-flight requests and holds a verdict for five
  /// minutes, so a cart that rebuilds on every quantity tap does not re-ask.
  void _checkAll(CartState state) {
    if (state is! CartLoaded) return;
    final stock = context.read<StockCubit>();
    for (final item in state.items) {
      stock.ensure(item.product.materialNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return BlocConsumer<CartCubit, CartState>(
      // A line added after the first frame gets checked too.
      listener: (_, state) => _checkAll(state),
      builder: (context, state) {
        final items = state is CartLoaded ? state.items : const <CartItem>[];

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: items.isEmpty
              ? const SizedBox(width: double.infinity)
              : Container(
                  padding: EdgeInsets.all(context.rr(16)),
                  decoration: BoxDecoration(
                    color: colors.card,
                    border: Border(
                      top: BorderSide(color: colors.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'orders.quotation.cart_preview_title'.tr,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(14),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: context.rh(12)),
                      BlocBuilder<StockCubit,
                          Map<String, MaterialAvailability>>(
                        builder: (context, stock) => ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => Divider(
                            color: colors.divider,
                            height: 16,
                          ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _CartPreviewRow(
                              // Keyed by the line, not the position. The
                              // stepper holds a local quantity so it can move
                              // before the cart write returns; without a key,
                              // removing a line slides the next one into that
                              // slot and it inherits the previous line's
                              // pending number.
                              key: ValueKey(item.id),
                              item: item,
                              stock: stock[item.product.materialNumber],
                              // Address the line by its own id — customized
                              // lines share a product id, so keying on
                              // product.id would hit the wrong line.
                              onQuantityChanged: (qty) => context
                                  .read<CartCubit>()
                                  .updateQuantity(item.id, qty),
                              onRemove: () =>
                                  context.read<CartCubit>().removeItem(item.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _CartPreviewRow extends StatelessWidget {
  const _CartPreviewRow({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    this.stock,
  });

  final CartItem item;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;
  final MaterialAvailability? stock;

  bool get _hasDrawing =>
      item.drawingImagePath != null && localFileExists(item.drawingImagePath!);

  String? get _customSpecs {
    if (!item.isCustomized) return null;
    final parts = <String>[];
    final m = item.measurements;
    if (m != null && !m.isEmpty) parts.add(m.toSummaryString());
    if (item.appearance != null && item.appearance!.trim().isNotEmpty) {
      parts.add(item.appearance!.trim());
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final specs = _customSpecs;
    final lineTotal = PricingText.amountOrNull(item.lineTotalOrNull);

    bool hasBackendPrice = false;
    try {
      final p =
          context.watch<PricingCubit>().state[item.product.materialNumber];
      if (p != null && p.hasAmount) {
        hasBackendPrice = true;
      }
    } catch (_) {}

    // Static while the shape is being reviewed. Swapping this one line for
    // `context.watch<PromotionCubit>().of(item.product.materialCode)` is the
    // whole of the real wiring — the badge already takes the same type the
    // repository returns.
    final promo = DemoCartPromotions.evaluate(item);

    // Above the row, right-aligned, and *in the flow*. The first attempt
    // floated it with a Positioned at top-right, which is exactly where the
    // quantity stepper and the remove button already live — the badge landed
    // on top of both, and its own text was cut through by the stepper's
    // border. A row of its own costs ~18dp on promoted lines only.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (promo != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: CartPromotionBadge(
              evaluation: promo,
              onSeeDetail: () => showPromotionDetailSheet(
                context,
                promotion: promo.promotion,
                evaluation: promo,
              ),
            ),
          ),
          SizedBox(height: context.rh(6)),
        ],
        Row(
          children: [
            if (item.isCustomized) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: context.rh(40),
                  color: colors.surfaceSoft,
                  child: _hasDrawing
                      ? localFileImage((item.drawingImagePath!),
                          fit: BoxFit.cover)
                      : Icon(Icons.tune_rounded,
                          size: context.rr(18), color: colors.accentPurple),
                ),
              ),
              SizedBox(width: context.rw(10)),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          context.localized(item.product.displayName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: context.rsp(13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.isCustomized) ...[
                        SizedBox(width: context.rw(6)),
                        Text('✏️',
                            style: TextStyle(
                                fontSize: context.rsp(11),
                                color: colors.accentPurple)),
                      ],
                    ],
                  ),
                  if (specs != null) ...[
                    SizedBox(height: context.rh(2)),
                    Text(
                      specs,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(11),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: context.rh(3)),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: context.rw(6),
                    runSpacing: context.rh(3),
                    children: [
                      if (item.isPricePending) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rw(6),
                            vertical: context.rh(2),
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(context.rr(4)),
                            border: Border.all(
                              color: colors.warning.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: context.rr(11),
                                color: colors.warningAlt,
                              ),
                              SizedBox(width: context.rw(3)),
                              Flexible(
                                child: Text(
                                  "Material doesn't have price",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.warningAlt,
                                    fontSize: context.rsp(10.5),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final price = await showManualPriceInputSheet(
                              context: context,
                              item: item,
                              currentPrice: item.isManualPrice
                                  ? item.unitPriceOverride
                                  : null,
                            );
                            if (context.mounted && price != null) {
                              await context.read<CartCubit>().updateUnitPrice(
                                    item.id,
                                    price > 0 ? price : null,
                                    isManualPrice: true,
                                  );
                            }
                          },
                          borderRadius: BorderRadius.circular(context.rr(6)),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rw(8),
                              vertical: context.rh(3),
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(context.rr(6)),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: context.rw(13),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: context.rw(3)),
                                Flexible(
                                  child: Text(
                                    'Input Price (USD)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: context.rsp(11),
                                      fontWeight: FontWeight.w800,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (item.isManualPrice && !hasBackendPrice) ...[
                        InkWell(
                          onTap: () async {
                            final price = await showManualPriceInputSheet(
                              context: context,
                              item: item,
                              currentPrice: item.unitPriceOverride,
                            );
                            if (context.mounted && price != null) {
                              await context.read<CartCubit>().updateUnitPrice(
                                    item.id,
                                    price > 0 ? price : null,
                                    isManualPrice: true,
                                  );
                            }
                          },
                          borderRadius: BorderRadius.circular(context.rr(4)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${item.unitPrice.toStringAsFixed(2)}/${item.unit}',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF60A5FA)
                                      : colors.brandNavy,
                                  fontSize: context.rsp(13),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: context.rw(4)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rw(4),
                                  vertical: context.rh(1.5),
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(context.rr(4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '(Manual USD)',
                                      style: TextStyle(
                                        fontSize: context.rsp(9.5),
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    SizedBox(width: context.rw(2)),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: context.rw(9),
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          '\$${item.unitPrice.toStringAsFixed(2)}/${item.unit}',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF60A5FA)
                                    : colors.brandNavy,
                            fontSize: context.rsp(13),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (lineTotal != null) ...[
                        Text(
                          lineTotal,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF60A5FA)
                                    : colors.brandNavy,
                            fontSize: context.rsp(13.5),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (stock != null) ...[
                        StockAvailabilityBadge(
                          availability: stock,
                          compact: true,
                        ),
                      ],
                    ],
                  ),

                  // The cart is where a rep checks what they have committed to, so
                  // it is where the discount has to be legible. Until now these
                  // rows showed a line total quietly reduced by a percentage that
                  // appeared nowhere — a number the rep could not explain to the
                  // depot reading over their shoulder.
                  //
                  // Compact here: the figure, not its provenance. The full
                  // attribution is one scroll down in the quotation preview.
                  LineDiscountChips(item: item, compact: true),
                ],
              ),
            ),
            // The same control the product card uses, rather than a second
            // hand-rolled pair of buttons.
            //
            // The pair it replaces had no number entry at all: the quantity was a
            // `Text`, so a rep correcting a line to 250 held `+` two hundred and
            // fifty times or deleted the line and started again. It also carried
            // its own copy of the enable rule, which is exactly how two controls
            // for one value drift apart.
            CartQuantityStepper(
              quantity: item.quantity.round(),
              onChanged: (value) => onQuantityChanged(value.toDouble()),
            ),
            SizedBox(width: context.rw(8)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.all(context.rr(6)),
                  child: Icon(
                    Icons.close_rounded,
                    size: context.rr(16),
                    color: colors.textHint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
