import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Bottom sheet allowing sales representatives to input or update a manual
/// unit price in USD (default currency) for quotation lines or catalog products
/// when backend or SAP pricing is unavailable.
Future<double?> showManualPriceInputSheet({
  required BuildContext context,
  CartItem? item,
  Product? product,
  String? unit,
  double? currentPrice,
}) {
  final resolvedProduct = item?.product ?? product;
  if (resolvedProduct == null) return Future.value(null);

  // Defense-in-depth: If the material already has a successful backend price,
  // manual pricing is strictly disallowed.
  try {
    final p =
        context.read<PricingCubit>().state[resolvedProduct.materialNumber];
    if (p != null && p.hasAmount) {
      return Future.value(null);
    }
  } catch (_) {}

  final resolvedUnit = (item?.unit.isNotEmpty == true ? item?.unit : null) ??
      (unit?.isNotEmpty == true ? unit : null) ??
      (resolvedProduct.unit.isNotEmpty ? resolvedProduct.unit : 'unit');

  final colors = Theme.of(context).extension<AppThemeColors>()!;
  final scheme = Theme.of(context).colorScheme;
  final initial = currentPrice ?? item?.unitPriceOverride;

  final controller = TextEditingController(
    text: (initial != null && initial > 0) ? initial.toStringAsFixed(2) : '',
  );

  return showModalBottomSheet<double?>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    backgroundColor: colors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rh(14)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.attach_money_rounded,
                          color: scheme.primary,
                          size: context.rw(22),
                        ),
                      ),
                      SizedBox(width: context.rw(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manual Unit Price (USD)',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: context.rsp(16),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Currency: USD (Default) · Per $resolvedUnit',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: context.rsp(12),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rh(12)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolvedProduct.materialCode.isNotEmpty
                              ? 'Material: ${resolvedProduct.materialCode}'
                              : 'SKU: ${resolvedProduct.sku}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: context.rh(2)),
                        Text(
                          context.localized(resolvedProduct.displayName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: context.rsp(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rh(16)),
                  Text(
                    'Input Price (USD):',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.rh(6)),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,4}')),
                    ],
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '\$',
                          style: TextStyle(
                            fontSize: context.rsp(18),
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 0, minHeight: 0),
                      suffixText: 'USD / $resolvedUnit',
                      suffixStyle: TextStyle(
                        fontSize: context.rsp(13),
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                      hintText: '0.00',
                      filled: true,
                      fillColor: colors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: scheme.primary, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rh(20)),
                  Row(
                    children: [
                      if (initial != null) ...[
                        OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(-1.0), // clear
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(color: scheme.error),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Clear'),
                        ),
                        SizedBox(width: context.rw(10)),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final text = controller.text.trim();
                            final val = double.tryParse(text);
                            if (val != null && val > 0) {
                              Navigator.of(context).pop(val);
                            } else {
                              Navigator.of(context).pop(-1.0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Price (USD)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
