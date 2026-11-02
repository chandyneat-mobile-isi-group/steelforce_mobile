import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_card_shell.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_drafts_sheet.dart';

/// Compact Home "Continue Working (N)" card shown when there is more than one
/// draft (or only backend drafts); tapping it opens the all-drafts sheet.
class ContinueWorkingMultiDraftCard extends StatelessWidget {
  const ContinueWorkingMultiDraftCard({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return ContinueWorkingCardShell(
      child: InkWell(
        onTap: () => openContinueWorkingDraftsSheet(context),
        borderRadius: BorderRadius.circular(context.rr(12)),
        child: Row(
          children: [
            // Dual-Bordered Icon Avatar Badge
            const ContinueWorkingIconBadge(padding: 8, iconSize: 20),
            SizedBox(width: context.rw(12)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sync.continue_working'.trParams({'count': count}),
                    style: TextStyle(
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: context.rh(2)),
                  Text(
                    'sync.unfinished_drafts'.tr,
                    style: TextStyle(
                      fontSize: context.rsp(12),
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: context.rsp(22),
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
