import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/preview/quotation_preview_chip.dart';

/// The depot's standing discount agreements, one chip each.
class QuotationAgreementChips extends StatelessWidget {
  const QuotationAgreementChips({super.key, required this.agreements});

  final List<DepotAgreement> agreements;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final ag in agreements)
          QuotationPreviewChip(
            icon: Icons.lock_outline_rounded,
            label:
                'Agreement: ${ag.percent.toStringAsFixed(1)}% (${ag.category})',
            foreground: colors.brandNavy,
            background: colors.surfaceSoft,
            borderColor: colors.border,
            fontWeight: FontWeight.w600,
          ),
      ],
    );
  }
}

/// The server's warnings on this quotation, shown by message or, failing
/// that, by code.
class QuotationWarningsPanel extends StatelessWidget {
  const QuotationWarningsPanel({super.key, required this.warnings});

  final List<QuotationWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      padding: EdgeInsets.all(context.rw(10)),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(context.rr(8)),
        border: Border.all(color: colors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in warnings)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.rh(2)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: context.rw(14),
                    color: colors.warningAlt,
                  ),
                  SizedBox(width: context.rw(6)),
                  Expanded(
                    child: Text(
                      w.message ?? w.code,
                      style: TextStyle(
                        fontSize: context.rsp(11),
                        color: colors.warningAlt,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
