import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_actions.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_buttons.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_card_shell.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_returned_note.dart';

/// Home "Continue Working" card for exactly one local draft: header with
/// discard, the framed draft summary, and Submit / Continue buttons.
class ContinueWorkingDraftCard extends StatelessWidget {
  const ContinueWorkingDraftCard({
    super.key,
    required this.draft,
    this.returned = false,
    this.returnReason,
  });
  final Quotation draft;

  /// An administrator sent this back from review.
  final bool returned;
  final String? returnReason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ContinueWorkingCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Dual-Bordered Icon Avatar Badge
              const ContinueWorkingIconBadge(padding: 6, iconSize: 18),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Text(
                  'sync.continue_previous'.tr,
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              ContinueWorkingDiscardButton(draft: draft),
            ],
          ),
          SizedBox(height: context.rh(10)),
          _DraftSummary(
            draft: draft,
            returned: returned,
            returnReason: returnReason,
          ),
          SizedBox(height: context.rh(14)),
          Row(
            children: [
              Expanded(
                child: ContinueWorkingOutlinedButton(
                  label: 'common.submit'.tr,
                  onPressed: () => submitDraftForReview(context, draft),
                ),
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: ContinueWorkingFilledButton(
                  label: 'common.continue'.tr,
                  onPressed: () => continueLocalDraft(context, draft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Traditional framed sub-container: quotation number, subtitle, and the
/// returned-by-admin note.
class _DraftSummary extends StatelessWidget {
  const _DraftSummary({
    required this.draft,
    required this.returned,
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
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(10), vertical: context.rh(8)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(8)),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sync.quotation_n'.trParams({'id': draft.id}),
            style: TextStyle(
              fontSize: context.rsp(13),
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          SizedBox(height: context.rh(3)),
          Text(
            continueWorkingDraftSubtitle(draft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.rsp(12),
              color: colors.textSecondary,
            ),
          ),
          if (returned) ...[
            SizedBox(height: context.rh(6)),
            ContinueWorkingReturnedNote(reason: returnReason),
          ],
        ],
      ),
    );
  }
}
