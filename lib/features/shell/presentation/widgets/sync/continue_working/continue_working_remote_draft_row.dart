import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_error_l10n.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_actions.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_buttons.dart';

/// A still-editable document on the Admin backend with no copy on this device.
/// It is edited and submitted on the document screen, online — there is no
/// local draft to submit from here, and no local discard for it.
class ContinueWorkingRemoteDraftRow extends StatelessWidget {
  const ContinueWorkingRemoteDraftRow({super.key, required this.draft});
  final QuotationSummary draft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sync.quotation_n'.trParams({'id': draft.number}),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: context.rsp(13.5),
              color: scheme.primary,
            ),
          ),
          SizedBox(height: context.rh(2)),
          Text(
            'sync.on_admin_server'.trParams({
              'who': draft.depotName,
              'count': draft.lineCount,
              'status': localizedRemoteStatus(draft.status),
            }),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: context.rsp(11.5), color: colors.textSecondary),
          ),
          SizedBox(height: context.rh(10)),
          Align(
            alignment: Alignment.centerRight,
            child: ContinueWorkingFilledButton(
              label: 'common.continue'.tr,
              onPressed: () {
                Navigator.of(context).pop();
                continueRemoteDraft(context, draft);
              },
            ),
          ),
        ],
      ),
    );
  }
}
