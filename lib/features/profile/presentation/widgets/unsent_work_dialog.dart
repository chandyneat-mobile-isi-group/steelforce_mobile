import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// Shown instead of the sign-out confirmation while work saved on this device
/// has not reached the server — signing out would delete it.
///
/// Lists what is waiting by kind (depot registrations, check-ins, quotations,
/// check-outs, …) in the order it is sent, so the rep can see what is held
/// up rather than a bare number.
///
/// Resolves to `true` when the rep chooses **Open Sync Center** — the caller
/// opens it, where the work is sent, retried or fixed; `false`/`null` when
/// the dialog is closed.
Future<bool?> showUnsentWorkDialog({
  required BuildContext context,
  required List<UnsentWorkCount> initial,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => UnsentWorkDialog(items: initial),
    );

class UnsentWorkDialog extends StatelessWidget {
  const UnsentWorkDialog({super.key, required this.items});

  final List<UnsentWorkCount> items;

  int get _total => items.fold(0, (sum, i) => sum + i.unsent);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      scrollable: true,
      title: SizedBox(
        height: 100,
        child: Stack(
          children: [
            const Positioned.fill(
              child: BrandWallpaperBackground(
                style: BrandWallpaperStyle.vivid,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(context, false),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? colors.card : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  color: scheme.primary,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'profile.unsent_title'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'profile.unsent_body'.trParams({'count': _total}),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSoft : scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 56, color: colors.divider),
                    _KindRow(item: items[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSecondary,
          ),
          child: Text('common.close'.tr),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.sync_rounded, size: 18),
          label: Text('profile.open_sync_center'.tr),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

/// One kind of waiting work: icon, name, how many, and how many of those
/// wait on the rep rather than on the connection.
class _KindRow extends StatelessWidget {
  const _KindRow({required this.item});
  final UnsentWorkCount item;

  static (IconData, String) _look(UnsentWorkKind kind) => switch (kind) {
        UnsentWorkKind.depotRegistrations => (
            Icons.storefront_outlined,
            'sync_kind.depot_registrations',
          ),
        UnsentWorkKind.adHocVisits => (
            Icons.add_location_alt_outlined,
            'sync_kind.ad_hoc_visits',
          ),
        UnsentWorkKind.checkIns => (Icons.login_rounded, 'sync_kind.check_ins'),
        UnsentWorkKind.quotations => (
            Icons.receipt_long_outlined,
            'sync_kind.quotations',
          ),
        UnsentWorkKind.checkOuts => (
            Icons.logout_rounded,
            'sync_kind.check_outs',
          ),
        UnsentWorkKind.visitRecords => (
            Icons.inventory_2_outlined,
            'sync_kind.visit_records',
          ),
        UnsentWorkKind.other => (Icons.more_horiz_rounded, 'sync_kind.other'),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (icon, key) = _look(item.kind);

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key.tr,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.needsAction > 0)
                    Text(
                      'sync_kind.needs_action'
                          .trParams({'count': item.needsAction}),
                      style: TextStyle(color: colors.warning, fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.unsent}',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
