import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_actions.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_buttons.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_returned_note.dart';

/// One local draft in the all-drafts sheet: number, subtitle, returned note,
/// and Discard / Submit / Continue actions.
class ContinueWorkingDraftRow extends StatelessWidget {
  const ContinueWorkingDraftRow({
    super.key,
    required this.draft,
    this.returned = false,
    this.returnReason,
  });
  final Quotation draft;
  final bool returned;
  final String? returnReason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: AppColors.steelRim.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: context.rr(6),
            offset: Offset(0, context.rh(3)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sync.quotation_n'.trParams({'id': draft.id}),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: context.rsp(13.5),
              color: scheme.primary,
            ),
          ),
          SizedBox(height: context.rh(2)),
          Text(
            continueWorkingDraftSubtitle(draft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: context.rsp(11.5), color: colors.textSecondary),
          ),
          if (returned) ...[
            SizedBox(height: context.rh(6)),
            ContinueWorkingReturnedNote(reason: returnReason),
          ],
          SizedBox(height: context.rh(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => confirmDiscardDraft(context, draft),
                child: Text(
                  'common.discard'.tr,
                  style: TextStyle(
                    fontSize: context.rsp(12),
                    color: colors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: context.rw(4)),
              ContinueWorkingOutlinedButton(
                label: 'common.submit'.tr,
                onPressed: () => submitDraftForReview(context, draft),
              ),
              SizedBox(width: context.rw(8)),
              ContinueWorkingFilledButton(
                label: 'common.continue'.tr,
                onPressed: () {
                  Navigator.of(context).pop();
                  continueLocalDraft(context, draft);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
