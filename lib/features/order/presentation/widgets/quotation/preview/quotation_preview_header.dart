import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/preview/quotation_preview_chip.dart';
import 'package:steelforce/shared/widgets/brand_logo.dart';

/// The quotation preview's letterhead: wordmark, title, who it is for, the
/// server status chips, and the optional "enlarge" button in the corner.
class QuotationPreviewHeader extends StatelessWidget {
  const QuotationPreviewHeader({
    super.key,
    this.shopName,
    required this.isEstimate,
    required this.requiredApprovalLevel,
    this.onEnlargeTap,
  });

  final String? shopName;
  final bool isEstimate;
  final int requiredApprovalLevel;
  final VoidCallback? onEnlargeTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final needsApproval = requiredApprovalLevel > 0;
    final approvalTone = needsApproval ? colors.warning : colors.success;
    final approvalInk = needsApproval ? colors.warningAlt : colors.success;

    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The ISI Group wordmark, ink chosen from the theme —
              // this preview sits on `colors.card`, which follows the
              // app theme, so dark ink in light mode and light ink in
              // dark. Replaces the two hand-picked rasters
              // (`isi_main_screen_logo.png` / `darkmood_logo.jpg`),
              // which were drawn `BoxFit.cover` into a 120x40 box the
              // artwork does not fit — that cropped the wordmark.
              // The issuing company, not the app: a quotation is an ISI Steel
              // document, matching the PDF it previews.
              BrandLogo(height: context.rh(40), mark: BrandMark.isiSteel),
              SizedBox(height: context.rh(6)),
              Text(
                'orders.quotation.builder_title'.tr,
                style: TextStyle(
                  fontSize: context.rsp(14),
                  fontWeight: FontWeight.w900,
                  color: colors.brandNavy,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: context.rh(2)),
              Text(
                '${shopName ?? 'orders.quotation_extra.walk_in'.tr} · ${'orders.quotation_extra.today'.tr}',
                style: TextStyle(
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: context.rh(8)),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isEstimate)
                    QuotationPreviewChip(
                      icon: Icons.schedule_rounded,
                      label: 'Estimate (SAP Offline)',
                      foreground: colors.warningAlt,
                      background: colors.warning.withValues(alpha: 0.12),
                      borderColor: colors.warning.withValues(alpha: 0.35),
                    ),
                  QuotationPreviewChip(
                    icon: needsApproval
                        ? Icons.shield_outlined
                        : Icons.check_circle_outline_rounded,
                    label: needsApproval
                        ? 'Level $requiredApprovalLevel Approval Required'
                        : 'Auto-Approved',
                    foreground: approvalInk,
                    background: approvalTone.withValues(alpha: 0.12),
                    borderColor: approvalTone.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onEnlargeTap != null)
          Positioned(
            right: 0,
            top: 0,
            child: _EnlargeButton(onTap: onEnlargeTap!),
          ),
      ],
    );
  }
}

class _EnlargeButton extends StatelessWidget {
  const _EnlargeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.rr(8)),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(10), vertical: context.rh(5)),
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(context.rr(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fullscreen_rounded,
              size: context.rw(14),
              color: colors.brandNavy,
            ),
            SizedBox(width: context.rw(4)),
            Text(
              'orders.quotation_extra.enlarge'.tr,
              style: TextStyle(
                fontSize: context.rsp(11),
                fontWeight: FontWeight.w700,
                color: colors.brandNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
