import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/platform/storage/local_files.dart';
import 'package:flutter/material.dart';

import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class QuotationItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback? onRemove;

  const QuotationItemCard({
    super.key,
    required this.item,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasDrawing = item.drawingImagePath != null &&
        localFileExists(item.drawingImagePath!);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isCustomized
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
          width: item.isCustomized ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.rr(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail: Drawing or Base Product
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 60,
                    height: context.rh(60),
                    color: colorScheme.surfaceContainerHigh,
                    child: hasDrawing
                        ? localFileImage(
                            (item.drawingImagePath!),
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
                SizedBox(width: context.rw(12)),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.localized(item.product.displayName),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (item.isCustomized) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '✏️ Customized',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: context.rh(4)),
                      Text(
                        // Quantity and unit always read normally; only the
                        // amount drops out while the line is unpriced.
                        item.isPricePending
                            ? '${item.quantity.toStringAsFixed(0)} ${item.unit}'
                            : '${item.quantity.toStringAsFixed(0)} ${item.unit}'
                                ' × \$${item.unitPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                if (onRemove != null)
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: context.rr(20), color: colorScheme.error),
                    onPressed: onRemove,
                  ),
              ],
            ),

            // Customized specs summary
            if (item.isCustomized && item.measurements != null) ...[
              const Divider(height: 16),
              Container(
                padding: EdgeInsets.all(context.rr(8)),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.straighten_rounded,
                        size: context.rr(16), color: colorScheme.primary),
                    SizedBox(width: context.rw(6)),
                    Text(
                      item.measurements!.toSummaryString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (item.appearance != null && item.appearance!.isNotEmpty) ...[
              SizedBox(height: context.rh(6)),
              Row(
                children: [
                  Icon(Icons.palette_outlined,
                      size: context.rr(16),
                      color: colorScheme.onSurfaceVariant),
                  SizedBox(width: context.rw(6)),
                  Expanded(
                    child: Text(
                      'Finish: ${item.appearance}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (item.customizationDescription != null &&
                item.customizationDescription!.isNotEmpty) ...[
              SizedBox(height: context.rh(4)),
              Text(
                'Note: ${item.customizationDescription}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
