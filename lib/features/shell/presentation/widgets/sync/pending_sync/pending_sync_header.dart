import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/pending_sync_now_button.dart';
import 'package:steelforce/shared/widgets/sheet_close_button.dart';

/// The Sync Center's header: grabber, cloud icon + title, the Sync Now and
/// close buttons, and the "N waiting / everything synced" summary line.
class PendingSyncHeader extends StatelessWidget {
  const PendingSyncHeader({
    super.key,
    required this.total,
    required this.showSyncNow,
    required this.isSyncing,
  });

  /// Items waiting across every kind of saved work.
  final int total;

  /// Whether anything is left to send, so Sync Now is worth showing.
  final bool showSyncNow;

  /// Whether any send is in progress.
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _grabber(colors.border),
        SizedBox(height: context.rh(12)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.rr(8)),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_upload_outlined,
                  size: context.rr(20), color: scheme.primary),
            ),
            SizedBox(width: context.rw(10)),
            Expanded(
              child: Text('sync.center_title'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: context.rsp(17),
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface)),
            ),
            if (showSyncNow)
              // Any send in progress — this button's, a card's
              // Sync, or an automatic drain — runs the same
              // queue.
              PendingSyncNowButton(isSyncing: isSyncing),
            SizedBox(width: context.rw(6)),
            const SheetCloseButton(),
          ],
        ),
        // Full width under the title row, so the summary keeps
        // one line beside the Sync Now and close buttons.
        Text(
          total == 0
              ? 'sync.everything_synced'.tr
              : 'sync_center.summary.waiting'.trParams({'count': total}),
          style:
              TextStyle(color: colors.textSecondary, fontSize: context.rsp(12)),
        ),
      ],
    );
  }

  Widget _grabber(Color color) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
