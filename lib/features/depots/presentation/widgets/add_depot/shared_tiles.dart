part of '../add_depot_bottom_sheet.dart';

/// Chips, toggles, notices and action tiles. Split out of shared_components.dart for size.
extension _SharedTilesExtension on _AddDepotBottomSheetState {
  Widget _infoChip(IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(12),
          vertical: context.rh(10),
        ),
        decoration: BoxDecoration(
          color: context.appColors.border.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: _fontSize(16),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _fontSize(12),
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _moreToggle({
    required bool expanded,
    required VoidCallback onTap,
    String? labelCollapsed,
  }) =>
      InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: _fontSize(20),
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                expanded
                    ? 'add_depot.show_less'.tr
                    : (labelCollapsed ?? 'add_depot.more_details'.tr),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: _fontSize(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

  /// Moved here from the photos step — it belongs next to Payment Term,
  /// which is the field that actually triggers credit review.
  Widget _creditNotice() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.appColors.warningAlt.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.appColors.warningAlt.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_outlined,
                color: context.appColors.warningAlt, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'add_depot.credit_notice'.tr,
                style: TextStyle(
                  color: context.appColors.warningAlt,
                  fontSize: _fontSize(11.5),
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _actionTile({
    required String label,
    required String sub,
    required IconData icon,
    required bool completed,
    required VoidCallback onTap,
    bool isUploading = false,
    bool hasError = false,
  }) {
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: widget.isTablet ? 14 : context.rw(10),
          vertical: widget.isTablet ? 10 : context.rh(8),
        ),
        decoration: BoxDecoration(
          color: hasError
              ? const Color(0xFFFEF2F2)
              : (completed ? const Color(0xFFF0FDF4) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError
                ? Theme.of(context).colorScheme.error
                : (completed
                    ? context.appColors.success
                    : const Color(0xFFE2E8F0)),
            width: (completed || hasError) ? 1.5 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasError
                    ? Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.12)
                    : (completed
                        ? context.appColors.success.withValues(alpha: 0.12)
                        : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: _fontSize(17),
                  color: hasError
                      ? Theme.of(context).colorScheme.error
                      : (completed
                          ? context.appColors.success
                          : Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: _fontSize(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasError
                          ? Theme.of(context).colorScheme.error
                          : (isUploading
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B)),
                      fontSize: _fontSize(11),
                      fontWeight: (isUploading || hasError)
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (isUploading)
              SizedBox(
                width: _fontSize(18),
                height: _fontSize(18),
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : (completed
                        ? Icons.check_circle_rounded
                        : Icons.add_a_photo_rounded),
                color: hasError
                    ? Theme.of(context).colorScheme.error
                    : (completed
                        ? context.appColors.success
                        : const Color(0xFF94A3B8)),
                size: _fontSize(18),
              ),
          ],
        ),
      ),
    );
  }
}
