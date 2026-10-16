import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Bottom sheet allowing sales representatives to input a manual discount
/// percentage on a quotation line, respecting the server-provided manual discount limit.
Future<double?> showManualDiscountInputSheet({
  required BuildContext context,
  required CartItem item,
  double? currentDiscountPercent,
  double maxDiscountPercent = 10.0,
  List<DepotAgreement> agreements = const [],
  List<double>? suggestedChips,
}) {
  final colors = Theme.of(context).extension<AppThemeColors>()!;
  final scheme = Theme.of(context).colorScheme;
  final initial = currentDiscountPercent ?? item.discountPercent;

  final controller = TextEditingController(
    text: (initial > 0) ? initial.toStringAsFixed(1) : '',
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
        final currentText = controller.text.trim();
        final entered = double.tryParse(currentText);
        final isExceeded = entered != null && entered > maxDiscountPercent;
        final isNegative = entered != null && entered < 0;
        final isValid = entered != null && !isExceeded && !isNegative;

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
                          Icons.percent_rounded,
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
                              'Line Manual Discount (%)',
                              style: TextStyle(
                                fontSize: context.rsp(16),
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            SizedBox(height: context.rh(2)),
                            Text(
                              context.localized(item.product.displayName),
                              style: TextStyle(
                                fontSize: context.rsp(12),
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rh(16)),

                  // Limit info banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: context.rw(16),
                          color: colors.brandNavy,
                        ),
                        SizedBox(width: context.rw(8)),
                        Expanded(
                          child: Text(
                            'Your manual limit: ${maxDiscountPercent.toStringAsFixed(1)}%. '
                            'Discounts above this require management approval.',
                            style: TextStyle(
                              fontSize: context.rsp(11),
                              color: colors.textSecondary,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (agreements.isNotEmpty) ...[
                    SizedBox(height: context.rh(8)),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: agreements.map((ag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Standing Agreement: -${ag.percent.toStringAsFixed(1)}% (${ag.category})',
                            style: TextStyle(
                              fontSize: context.rsp(10.5),
                              fontWeight: FontWeight.w600,
                              color: colors.success,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  SizedBox(height: context.rh(16)),

                  // Input row
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Discount Percentage',
                      hintText: 'e.g. 3.5',
                      suffixText: '%',
                      prefixIcon: const Icon(Icons.tune_rounded),
                      errorText: isExceeded
                          ? 'Limit is ${maxDiscountPercent.toStringAsFixed(1)}%'
                          : (isNegative ? 'Must be positive' : null),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rh(12)),

                  // Quick shortcut chips
                  Builder(
                    builder: (context) {
                      final chips =
                          suggestedChips ?? const [1.0, 2.0, 3.0, 5.0];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            label: const Text('0% (Reset)'),
                            onPressed: () {
                              controller.text = '0';
                              setState(() {});
                            },
                          ),
                          for (final chip in chips)
                            ActionChip(
                              label: Text(
                                '${chip.toStringAsFixed(chip.truncateToDouble() == chip ? 0 : 1)}%',
                              ),
                              onPressed: () {
                                controller.text = chip.toStringAsFixed(
                                  chip.truncateToDouble() == chip ? 0 : 1,
                                );
                                setState(() {});
                              },
                            ),
                          if (maxDiscountPercent > 0 &&
                              !chips.any(
                                  (c) => (c - maxDiscountPercent).abs() < 0.01))
                            ActionChip(
                              label: Text(
                                '${maxDiscountPercent.toStringAsFixed(maxDiscountPercent.truncateToDouble() == maxDiscountPercent ? 0 : 1)}% (Max)',
                              ),
                              onPressed: () {
                                controller.text =
                                    maxDiscountPercent.toStringAsFixed(
                                  maxDiscountPercent.truncateToDouble() ==
                                          maxDiscountPercent
                                      ? 0
                                      : 1,
                                );
                                setState(() {});
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: context.rh(20)),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: context.rw(12)),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (currentText.isEmpty || isValid)
                              ? () {
                                  final val = entered ?? 0.0;
                                  Navigator.of(context).pop(val);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Apply Discount'),
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
