import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One product-category row in [KpiCategoryBreakdown]: name, amount and a
/// coloured progress bar.
class KpiCategoryProgressRow extends StatelessWidget {
  const KpiCategoryProgressRow({
    super.key,
    required this.title,
    required this.amount,
    required this.progress,
    required this.color,
  });

  final String title;
  final String amount;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.rsp(13),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(width: context.rw(8)),
            Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: context.rsp(13),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(6)),
        Stack(
          children: [
            Container(
              height: context.rh(6),
              decoration: BoxDecoration(
                color: appColors.surfaceSoft,
                borderRadius: BorderRadius.circular(context.rr(6)),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: context.rh(6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(context.rr(6)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
